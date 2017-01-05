# RDF::Query::Algebra::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::BasicGraphPattern - Algebra class for BasicGraphPattern patterns

=head1 VERSION

This document describes RDF::Query::Algebra::BasicGraphPattern version 2.918.

=cut

package RDF::Query::Algebra::BasicGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed refaddr reftype);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap swatch);

######################################################################

our ($VERSION);
my %AS_SPARQL;
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

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

=item C<< quads >>

Returns a list of the (implicit) quads belonging to this BGP.

=cut

sub quads {
	my $self	= shift;
	my @triples	= $self->triples;
	my @quads;
	foreach my $t (@triples) {
		my @nodes	= $t->nodes;
		foreach my $i (0 .. 3) {
			my $n	= $nodes[ $i ];
			if (not blessed($n)) {
				if ($i == 3) {
					$nodes[ $i ]	= RDF::Trine::Node::Nil->new();
				} else {
					$nodes[ $i ]	= RDF::Query::Node::Variable->new();
				}
			}
		}
		my $st	= RDF::Trine::Statement::Quad->new( @nodes );
		push(@quads, $st);
	}
	return @quads;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my @triples	= sort map { $_->sse( $context ) } $self->triples;
	return sprintf(
		"(BGP\n${prefix}${indent}%s\n${prefix})",
		join("\n${prefix}${indent}", @triples)
	);
}

=item C<< explain >>

Returns a string serialization of the algebra appropriate for display on the
command line.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $string	= "${indent}basic graph pattern\n";
	
	foreach my $t ($self->triples) {
		$string	.= "${indent}${s}" . $t->as_sparql . "\n";
	}
	return $string;
}


=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	if (exists $AS_SPARQL{ refaddr( $self ) }) {
		return $AS_SPARQL{ refaddr( $self ) };
	} else {
		my $context	= shift;
# 		if (ref($context)) {
# 			$context	= { %$context };
# 		}
		my $indent	= shift || '';
		my @triples;
		foreach my $t ($self->triples) {
			push(@triples, $t->as_sparql( $context, $indent ));
		}
		my $string	= join("\n${indent}", @triples);
		$AS_SPARQL{ refaddr( $self ) }	= $string;
		return $string;
	}
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		patterns	=> [ map { $_->as_hash } $self->triples ],
	};
}

=item C<< as_spin ( $model ) >>

Adds statements to the given model to represent this algebra object in the
SPARQL Inferencing Notation (L<http://www.spinrdf.org/>).

=cut

sub as_spin {
	my $self	= shift;
	my $model	= shift;
	my @t		= $self->triples;
	my @nodes	= map { $_->as_spin( $model ) } @t;
	return @nodes;
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
	return RDF::Query::_uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->potentially_bound } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->definite_variables } $self->triples);
}

sub _referenced_blanks {
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

=item C<< connected >>

Returns true if the pattern is connected through shared variables, false otherwise.

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

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my @bf;
	my %var_to_num;
	my %use_count;
	my $counter	= 1;
	foreach my $t ($self->triples) {
		my $bf	= $t->bf;
		if ($bf =~ /f/) {
			$bf	= '';
			foreach my $n ($t->nodes) {
				if ($n->isa('RDF::Query::Node::Variable')) {
					my $name	= $n->name;
					my $num		= ($var_to_num{ $name } ||= $counter++);
					$use_count{ $name }++;
					$bf	.= "{${num}}";
				} else {
					$bf	.= 'b';
				}
			}
		}
		push(@bf, $bf);
	}
	my $bf	= join(',',@bf);
	if ($counter <= 10) {
		$bf	=~ s/[{}]//g;
	}
	return $bf;
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

sub DESTROY {
	my $self	= shift;
	delete $AS_SPARQL{ refaddr( $self ) };
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
