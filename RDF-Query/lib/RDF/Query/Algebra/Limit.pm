# RDF::Query::Algebra::Limit
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Limit - Algebra class for limiting query results

=cut

package RDF::Query::Algebra::Limit;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.100';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $pattern, $limit ) >>

Returns a new Sort structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $limit	= shift;
	return bless( [ $pattern, $limit ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $limit	= $self->limit;
	return ($pattern, $limit);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< limit >>

Returns the limit number of the pattern.

=cut

sub limit {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	if ($self->pattern->isa('RDF::Query::Algebra::Offset')) {
		my $l	= $self->limit;
		my $o	= $self->pattern->offset;
		return sprintf(
			"(slice %d %d\n${prefix}${indent}%s)",
			$o, $l,
			$self->pattern->pattern->sse( $context, "${prefix}${indent}" ),
		);
	} else {
		return sprintf(
			"(limit %s\n${prefix}${indent}%s)",
			$self->limit,
			$self->pattern->sse( $context, "${prefix}${indent}" ),
		);
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $string	= sprintf(
		"%s\nLIMIT %d",
		$self->pattern->as_sparql( $context, $indent ),
		$self->limit,
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'LIMIT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq($self->pattern->referenced_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
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
		return $class->new( $self->pattern->fixup( $query, $bridge, $base, $ns ), $self->limit );
	}
}

=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
