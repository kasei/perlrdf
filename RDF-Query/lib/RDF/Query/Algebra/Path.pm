# RDF::Query::Algebra::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Path - Algebra class for path patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Path version 2.202_01, released 30 January 2010.

=cut

package RDF::Query::Algebra::Path;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.202_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $start, [ $op, @paths ], $end )>

Returns a new Path structure.

=cut

sub new {
	my $class	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	return bless( [ $start, $path, $end ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->start, $self->path, $self->end);
}

=item C<< path >>

Returns the path description for this path expression.

=cut

sub path {
	my $self	= shift;
	return $self->[1];
}

=item C<< start >>

Returns the path origin node.

=cut

sub start {
	my $self	= shift;
	return $self->[0];
}

=item C<< end >>

Returns the path destination node.

=cut

sub end {
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
	
	die 'SSE serialization of path expressions not implemented';
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	die 'SPARQL serialization of path expressions not implemented';
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
	return 'PATH';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= grep { $_->isa('RDF::Query::Node::Variable') } ($self->start, $self->end);
	return RDF::Query::_uniq(map { $_->name } @vars);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	my @vars	= grep { $_->isa('RDF::Query::Node::Variable') } ($self->start, $self->end);
	return RDF::Query::_uniq(map { $_->name } @vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->referenced_variables;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
