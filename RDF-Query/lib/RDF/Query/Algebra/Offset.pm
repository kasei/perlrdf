# RDF::Query::Algebra::Offset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Offset - Algebra class for offseting query results

=head1 VERSION

This document describes RDF::Query::Algebra::Offset version 2.918.

=cut

package RDF::Query::Algebra::Offset;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<< new ( $pattern, $offset ) >>

Returns a new Sort structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $offset	= shift;
	return bless( [ $pattern, $offset ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $offset	= $self->offset;
	return ($pattern, $offset);
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

=item C<< offset >>

Returns the offset number of the pattern.

=cut

sub offset {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	return sprintf(
		"(offset %s\n${prefix}${indent}%s)",
		$self->offset,
		$self->pattern->sse( $context, "${prefix}${indent}" ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $string	= sprintf(
		"%s\nOFFSET %d",
		$self->pattern->as_sparql( $context, $indent ),
		$self->offset,
	);
	return $string;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		offset		=> $self->offset,
	};
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
	return RDF::Query::_uniq($self->pattern->referenced_variables);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return $self->pattern->potentially_bound;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
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
