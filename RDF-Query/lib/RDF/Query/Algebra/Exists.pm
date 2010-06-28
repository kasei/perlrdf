# RDF::Query::Algebra::Exists
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Exists - Algebra class for EXISTS and NOT EXISTS patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Exists version 2.901_01.

=cut

package RDF::Query::Algebra::Exists;

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
	$VERSION	= '2.901_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, $pattern, $exists, $not_flag )>

Returns a new EXISTS structure for the specified $pattern. If $not_flag is true,
the pattern will be interpreted as a NOT EXISTS pattern.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $exists	= shift;
	my $not		= shift;
	return bless( [ $pattern, $exists, $not ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern, $self->exists_pattern, $self->not_flag);
}

=item C<< pattern >>

Returns the base pattern (LHS) onto which the not-pattern joins.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< exists_pattern >>

Returns the not-pattern (RHS).

=cut

sub exists_pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< not_flag >>

Returns true if the pattern is a NOT EXISTS pattern.

=cut

sub not_flag {
	my $self	= shift;
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my $tag		= ($self->not_flag) ? 'not-exists' : 'exists';
	return sprintf(
		"(${tag}\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		$self->exists_pattern->sse( $context, "${prefix}${indent}" )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $tag		= ($self->not_flag) ? 'NOT EXISTS' : 'EXISTS';
	my $string	= sprintf(
		"%s\n${indent}${tag} %s",
		$self->pattern->as_sparql( $context, $indent ),
		$self->exists_pattern->as_sparql( $context, $indent ),
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
		exists		=> $self->exists_pattern->as_hash,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'EXISTS';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->referenced_variables, $self->exists_pattern->referenced_variables);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->binding_variables } $self->pattern);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
