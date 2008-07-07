# RDF::Query::Algebra::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::BasicGraphPattern - Algebra class for BasicGraphPattern patterns

=cut

package RDF::Query::Algebra::BasicGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( @triples )>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my @triples	= @_;
	foreach my $t (@triples) {
		unless ($t->isa('RDF::Trine::Statement')) {
			Carp::cluck;
			throw RDF::Query::Error::QueryPatternError -text => "Patterns belonging to a BGP must be graph statements";
		}
	}
	return bless( [ @triples ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->triples);
}

=item C<< triples >>

Returns a list of triples belonging to this BGP.

=cut

sub triples {
	my $self	= shift;
	return @$self;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(bgp %s)',
		join(' ', map { $_->sse( $context ) } $self->triples)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift || '';
	my @triples;
	foreach my $t ($self->triples) {
		push(@triples, $t->as_sparql( $context, $indent ));
	}
	my $string	= join("\n${indent}", @triples);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'BGP';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(map { $_->definite_variables } $self->triples);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub _check_duplicate_blanks {
	my $self	= shift;
	my %seen;
	foreach my $t ($self->triples) {
		my @blanks	= $t->referenced_blanks;
		foreach my $b (@blanks) {
			$seen{ $b }++;
		}
	}
	return [keys %seen];
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		my @nodes	= map { $_->fixup( $query, $bridge, $base, $ns ) } $self->triples;
		my $fixed	= $class->new( @nodes );
		return $fixed;
	}
}

=item C<< connected >>

Returns true if the pattern is connected through shared variables, fase otherwise.

=cut

sub connected {
	my $self	= shift;
	my @triples	= $self->triples;
	return 1 unless (scalar(@triples) > 1);
	
	my %index;
	my %variables;
	foreach my $i (0 .. $#triples) {
		my $t	= $triples[ $i ];
		$index{ $t->as_string }	= $i;
		foreach my $n ($t->nodes) {
			next unless ($n->isa('RDF::Trine::Node::Variable'));
			push( @{ $variables{ $n->name } }, $t );
		}
	}
	
	my @connected;
	foreach my $i (0 .. $#triples) {
		foreach my $j (0 .. $#triples) {
			$connected[ $i ][ $j ]	= ($i == $j) ? 1 : 0;
		}
	}
	
	my %seen;
	my @queue	= $triples[0];
	while (my $t = shift(@queue)) {
		my $string	= $t->as_string;
		next if ($seen{ $string }++);
		my @vars	= map { $_->name } grep { $_->isa('RDF::Trine::Node::Variable') } $t->nodes;
		my @connected_to	= map { @{ $variables{ $_ } } } @vars;
		foreach my $c (@connected_to) {
			my $cstring	= $c->as_string;
			my $i	= $index{$string};
			
			my $k		= $index{ $cstring };
			my @conn	= @{ $connected[$i] };
			$conn[ $k ]	= 1;
			foreach my $j (0 .. $#triples) {
				if ($conn[ $j ] == 1) {
					$connected[ $k ][ $j ]	= 1;
					$connected[ $j ][ $k ]	= 1;
				}
			}
			push(@queue, $c);
		}
	}
	
	foreach my $i (0 .. $#triples) {
		return 0 unless ($connected[0][$i] == 1);
	}
	return 1;
}

=item C<< subsumes ( $pattern ) >>

Returns true if the bgp subsumes the pattern, false otherwise.

=cut

sub subsumes {
	my $self	= shift;
	my $pattern	= shift;
	if ($pattern->isa('RDF::Trine::Statement')) {
		foreach my $t ($self->triples) {
			return 1 if ($t->subsumes($pattern));
		}
		return 0;
	} elsif ($pattern->isa('RDF::Query::Algebra::BasicGraphPattern')) {
		OUTER: foreach my $p ($pattern->triples) {
			foreach my $t ($self->triples) {
				next OUTER if ($t->subsumes($p));
			}
			return 0;
		}
		return 1;
	} else {
		return 0;
	}
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->triples );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->triples );
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	my $l		= Log::Log4perl->get_logger("rdf.query.algebra.basicgraphpattern");
	
	my @streams;
	my (@triples)	= $self->triples;
	my $t0			= [gettimeofday];
	foreach my $triple (@triples) {
		Carp::confess "not an algebra or rdf node: " . Dumper($triple) unless ($triple->isa('RDF::Trine::Statement'));
		my $stream	= $triple->execute( $query, $bridge, $bound, $context, %args );
		push(@streams, $stream);
	}
	if (@streams) {
		while (@streams > 1) {
			my $a	= shift(@streams);
			my $b	= shift(@streams);
			my $stream	= RDF::Trine::Iterator::Bindings->join_streams( $a, $b );
			unshift(@streams, $stream);
		}
	} else {
		push(@streams, RDF::Trine::Iterator::Bindings->new([{}], []));
	}
	my $stream	= shift(@streams);

	if (my $log = $query->logger) {
		$l->debug("logging bgp execution time");
		my $elapsed = tv_interval ( $t0 );
		$log->push_key_value( 'execute_time-bgp', $self->as_sparql, $elapsed );
	} else {
		$l->debug("no logger present for bgp execution time");
	}

	return $stream;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
