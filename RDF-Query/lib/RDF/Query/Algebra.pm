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

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
