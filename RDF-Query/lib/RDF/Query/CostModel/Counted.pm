# RDF::Query::CostModel::Counted
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::CostModel::Counted - Execution cost estimator

=head1 VERSION

This document describes RDF::Query::CostModel::Counted version 2.201_01, released 27 January 2010.

=head1 METHODS

=over 4

=cut

package RDF::Query::CostModel::Counted;

our ($VERSION);
BEGIN {
	$VERSION	= '2.201_01';
}

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::CostModel::Naive);

use RDF::Query::Error qw(:try);

use Set::Scalar;
use Data::Dumper;
use Scalar::Util qw(blessed);

sub _cost_triple {
	my $self	= shift;
	my $triple	= shift;
	my $context	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $triple->sse( {}, '' ) );
	return $self->_cardinality( $triple, $context );
}

sub _cardinality_triple {
	my $self	= shift;
	my $pattern	= shift;
	my $context	= shift;
	my $model	= $context->model;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	my $size	= $self->_size( $context );
	my $card	= $size * $model->node_count( $pattern->nodes );
	$l->debug( 'Cardinality of triple is : ' . $card );
	return $card;
}

sub _size {
	my $self	= shift;
	my $context	= shift;
	my $model	= $context->model;
	my $size	= $model->node_count();
	return $size;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
