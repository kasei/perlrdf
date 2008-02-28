# RDF::Query::Algebra::TimeGraph
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::TimeGraph - Algebra class for temporal patterns

=cut

package RDF::Query::Algebra::TimeGraph;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

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

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(time %s %s %s)',
		$self->interval->sse( $context ),
		$self->pattern->sse( $context ),
		$self->time_triples->sse( $context ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

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
	return uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->referenced_variables,
		$self->time_triples->referenced_variables,
	);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(
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
