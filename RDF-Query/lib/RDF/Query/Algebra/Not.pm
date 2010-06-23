# RDF::Query::Algebra::Not
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Not - Algebra class for Not patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Not version 2.900.

=cut

package RDF::Query::Algebra::Not;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.900';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, $not_pattern )>

Returns a new Not structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $opt		= shift;
	return bless( [ $pattern, $opt ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern, $self->not_pattern);
}

=item C<< pattern >>

Returns the base pattern (LHS) onto which the not-pattern joins.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< not_pattern >>

Returns the not-pattern (RHS).

=cut

sub not_pattern {
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
	
	return sprintf(
		"(not\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		$self->not_pattern->sse( $context, "${prefix}${indent}" )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"%s\n${indent}NOT %s",
		$self->pattern->as_sparql( $context, $indent ),
		$self->not_pattern->as_sparql( $context, $indent ),
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
		not			=> $self->not_pattern->as_hash,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'NOT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->referenced_variables, $self->not_pattern->referenced_variables);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->binding_variables, $self->not_pattern->binding_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
