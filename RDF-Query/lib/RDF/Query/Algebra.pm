# RDF::Query::Algebra
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra - Base class for Algebra expressions

=head1 METHODS

=over 4

=cut

package RDF::Query::Algebra;

BEGIN {
	our $VERSION	= '2.002';
}

use strict;
use warnings;
no warnings 'redefine';

use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Data::Dumper;

use RDF::Query::Expression;
use RDF::Query::Expression::Alias;
use RDF::Query::Expression::Nary;
use RDF::Query::Expression::Binary;
use RDF::Query::Expression::Unary;
use RDF::Query::Expression::Function;

use RDF::Query::Algebra::BasicGraphPattern;
use RDF::Query::Algebra::Filter;
use RDF::Query::Algebra::GroupGraphPattern;
use RDF::Query::Algebra::Optional;
use RDF::Query::Algebra::Triple;
use RDF::Query::Algebra::Quad;
use RDF::Query::Algebra::Union;
use RDF::Query::Algebra::NamedGraph;
use RDF::Query::Algebra::Service;
use RDF::Query::Algebra::TimeGraph;
use RDF::Query::Algebra::Aggregate;
use RDF::Query::Algebra::Sort;
use RDF::Query::Algebra::Limit;
use RDF::Query::Algebra::Offset;
use RDF::Query::Algebra::Distinct;
use RDF::Query::Algebra::Path;

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @list;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			my @blanks	= $arg->referenced_blanks;
			push(@list, @blanks);
		}
	}
	return uniq(@list);
}

=item C<< referenced_functions >>

Returns a list of the Function URIs used in this algebra expression.

=cut

sub referenced_functions {
	my $self	= shift;
	my @list;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg)) {
			if ($arg->isa('RDF::Query::Expression::Function')) {
				push(@list, $arg->uri);
			} elsif ($arg->isa('RDF::Query::Algebra')) {
				my @funcs	= $arg->referenced_functions;
				push(@list, @funcs);
			}
		}
	}
	return uniq(@list);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@data, $arg->_check_duplicate_blanks);
		}
	}
	
	my %seen;
	foreach my $d (@data) {
		foreach my $b (@$d) {
			if ($seen{ $b }++) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
		}
	}
	
	return 1;
}

sub _check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push( @data, $arg->_check_duplicate_blanks );
		}
	}
	return @data;
}

=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base ));
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->bind_variables( $bound ));
		} elsif (blessed($arg) and $arg->isa('RDF::Trine::Node::Variable') and exists($bound->{ $arg->name })) {
			push(@args, $bound->{ $arg->name });
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< subpatterns_of_type ( $type [, $block] ) >>

Returns a list of Algebra patterns matching C<< $type >> (tested with C<< isa >>).
If C<< $block >> is given, then matching stops descending a subtree if the current
node is of type C<< $block >>, continuing matching on other subtrees.
This list includes the current algebra object if it matches C<< $type >>, and is
generated in infix order.

=cut

sub subpatterns_of_type {
	my $self	= shift;
	my $type	= shift;
	my $block	= shift;
	
	return if ($block and $self->isa($block));
	
	my @patterns;
	push(@patterns, $self) if ($self->isa($type));
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@patterns, $arg->subpatterns_of_type($type));
		}
	}
	return @patterns;
}

=item C<< nested_loop_local_join ( $outer_iterator, $inner_algebra, $query, $bridge, $bound, $context ) >>

Performs a natural, nested loop join, returning a new stream of joined results.

Items from C<< $outer_iterator >> are used as bound values to successive calls
to C<< $inner_algebra->execute >>.

=cut

sub nested_loop_local_join {
	my $self	= shift;
	my $outer	= shift;
	my $inner	= shift;
	my $query	= shift;
	my $bridge	= shift;
	my $bound	= shift || {};
	my $context	= shift;
	my %args	= @_;
	
	Carp::confess unless ($outer->isa('RDF::Trine::Iterator::Bindings'));
	Carp::confess unless ($inner->isa('RDF::Query::Algebra'));
	my $l		= Log::Log4perl->get_logger("rdf.query.algebra");
	
	my $a		= $outer;
	
	no warnings 'uninitialized';
	
	my $rowa;
	my $inner_iter;
	my $need_new_a	= 1;
	my $sub	= sub {
		OUTER: while (1) {
			if ($need_new_a) {
				$rowa = $a->next or return undef;
				$l->debug("*** new outer tuple");
				$l->debug("OUTER: " . Dumper($rowa));
				my %tmpbound;
				foreach my $h ($bound, $rowa) {
					foreach my $k (keys %$h) {
						if (defined($h->{ $k })) {
							$tmpbound{ $k }	= $h->{ $k };
						}
					}
				}
				$l->debug("executing inner pattern " . $inner->as_sparql . " with bound values: " . '{' . join(', ', map { join('=', $_, ($tmpbound{$_}) ? $tmpbound{$_}->as_string : '(undef)') } (keys %tmpbound)) . '}' );
				$inner_iter		= $inner->execute( $query, $bridge, \%tmpbound, $context, %args ); #->project( @names );
				$need_new_a		= 0;
			}
			$l->debug("OUTER: " . Dumper($rowa));
			return undef unless ($rowa);
			LOOP: while (my $rowb = $inner_iter->next) {
				$l->debug("- INNER: " . Dumper($rowb));
				$l->debug("[--JOIN--] " . join(' ', map { my $row = $_; '{' . join(', ', map { join('=', $_, ($row->{$_}) ? $row->{$_}->as_string : '(undef)') } (keys %$row)) . '}' } ($rowa, $rowb)));
				my %keysa	= map {$_=>1} (keys %$rowa);
				my @shared	= grep { $keysa{ $_ } } (keys %$rowb);
				foreach my $key (@shared) {
					my $val_a	= $rowa->{ $key };
					my $val_b	= $rowb->{ $key };
					my $defined	= 0;
					foreach my $n ($val_a, $val_b) {
						$defined++ if (defined($n));
					}
					if ($defined == 2) {
						my $equal	= $val_a->equal( $val_b );
						unless ($equal) {
							$l->debug("can't join because mismatch of $key (" . join(' <==> ', map {$_->as_string} ($val_a, $val_b)) . ")");
							next LOOP;
						}
					}
				}
				
				my $row	= { (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
				if ($l->is_debug) {
					$l->debug("JOINED:");
					foreach my $key (keys %$row) {
						$l->debug("$key\t=> " . $row->{ $key }->as_string);
					}
				}
				return $row;
			}
			$need_new_a	= 1;
		}
	};
	
	my @names	= uniq( $outer->binding_names, $inner->referenced_variables );
	my $args	= $outer->_args;
	return $outer->_new( $sub, 'bindings', \@names, %$args );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
