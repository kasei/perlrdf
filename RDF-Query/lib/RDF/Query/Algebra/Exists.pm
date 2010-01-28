# RDF::Query::Algebra::Exists
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Exists - Algebra class for EXISTS and NOT EXISTS patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Exists version 2.201_01, released 27 January 2010.

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
	$VERSION	= '2.201_01';
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
	my $indent	= $context->{indent};
	
	my $tag		= ($self->not_flag) ? 'not-exists' : 'exists';
	return sprintf(
		"(${tag}\n${prefix}${indent}%s\n${prefix}${indent}%s)",
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
	my $tag		= ($self->not_flag) ? 'NOT EXISTS' : 'EXISTS';
	my $string	= sprintf(
		"%s\n${indent}${tag} %s",
		$self->pattern->as_sparql( $context, $indent ),
		$self->not_pattern->as_sparql( $context, $indent ),
	);
	return $string;
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
	return;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return;
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
		return $class->new( map { $_->fixup( $query, $bridge, $base, $ns ) } ($self->pattern, $self->not_pattern) );
	}
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
