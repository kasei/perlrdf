# RDF::Query::Algebra::TimeGraph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::TimeGraph - Algebra class for temporal patterns

=head1 VERSION

This document describes RDF::Query::Algebra::TimeGraph version 2.910.

=cut

package RDF::Query::Algebra::TimeGraph;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $interval, $pattern, $time_triples )>

Returns a new TimeGraph structure.

=cut

sub new {
	my $class		= shift;
	my @data		= @_;	# $interval, $pattern, $triples
	return bless( [ 'TIME', @data ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->interval, $self->pattern, $self->time_triples);
}

=item C<< interval >>

Returns the time interval node of the temporal graph expression.

=cut

sub interval {
	my $self	= shift;
	if (@_) {
		my $interval	= shift;
		$self->[1]		= $interval;
	}
	return $self->[1];
}

=item C<< pattern >>

Returns the graph pattern of the temporal graph expression.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< time_triples >>

Returns the triples describing the time interval of the temporal graph.

=cut

sub time_triples {
	my $self	= shift;
	return $self->[3];
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
		'(time\n${prefix}${indent}%s\n${prefix}${indent}%s\n${prefix}${indent}%s)',
		$self->interval->sse( $context, "${prefix}${indent}" ),
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		$self->time_triples->sse( $context, "${prefix}${indent}" ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $nindent	= $indent . "\t";
	my $string	= sprintf(
		"TIME %s %s",
		$self->interval->as_sparql( $context, $indent ),
		$self->pattern->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'TIME';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->referenced_variables,
		$self->time_triples->referenced_variables,
	);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->potentially_bound,
		$self->time_triples->potentially_bound,
	);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->definite_variables,
		$self->time_triples->definite_variables,
	);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
