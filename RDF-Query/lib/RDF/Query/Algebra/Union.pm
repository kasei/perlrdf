# RDF::Query::Algebra::Union
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Union - Algebra class for Union patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Union version 2.201, released 30 January 2010.

=cut

package RDF::Query::Algebra::Union;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.201';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $left, $right )>

Returns a new Union structure.

=cut

sub new {
	my $class	= shift;
	my $left	= shift;
	my $right	= shift;
	return bless( [ 'UNION', $left, $right ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->first, $self->second);
}

=item C<< first >>

Returns the first pattern (LHS) of the union.

=cut

sub first {
	my $self	= shift;
	return $self->[1];
}

=item C<< second >>

Returns the second pattern (RHS) of the union.

=cut


=item C<< patterns >>

Returns the two patterns belonging to the UNION pattern.

=cut

sub patterns {
	my $self	= shift;
	return ($self->first, $self->second);
}

sub second {
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
	
	return sprintf(
		"(union\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->first->sse( $context, "${prefix}${indent}" ),
		$self->second->sse( $context, "${prefix}${indent}" )
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
		"%s\n${indent}UNION\n${indent}%s",
		$self->first->as_sparql( $context, $indent ),
		$self->second->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'UNION';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->first->referenced_variables, $self->second->referenced_variables);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->first->binding_variables, $self->second->binding_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my $seta	= Set::Scalar->new( $self->first->definite_variables );
	my $setb	= Set::Scalar->new( $self->second->definite_variables );
	return $seta->intersection( $setb )->members;
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
		return $class->new( map { $_->fixup( $query, $bridge, $base, $ns ) } $self->patterns );
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
