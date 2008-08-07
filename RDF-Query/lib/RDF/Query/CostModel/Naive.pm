# RDF::Query::CostModel::Naive
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::CostModel::Naive - Execution cost estimator

=head1 METHODS

=over 4

=cut

package RDF::Query::CostModel::Naive;

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::CostModel);

use Set::Scalar;
use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);

=item C<< new () >>

Return a new cost model object.

=cut

sub new {
	my $class	= shift;
	my $self	= $class->SUPER::new( @_ );
	return $self;
}


sub _cost_service {
	my $self	= shift;
	my $plan	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . Dumper($plan) );
	return 2 * $self->cost( $plan->pattern );
}

sub _cost_nestedloop {
	my $self	= shift;
	my $bgp		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . Dumper($bgp) );
	return $self->_cardinality( $bgp );
}

sub _cost_triple {
	my $self	= shift;
	my $triple	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . Dumper($triple) );
	return $self->_cardinality( $triple );
}

sub _cardinality_triple {
	my $self	= shift;
	my $pattern	= shift;
	my $size	= $self->_size;
	my $bf		= $pattern->bf;
	my $f		= ($bf =~ tr/f//);
	my $r		= $f / 3;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	my $card	= ($self->_size ** $r);
	$l->debug( 'Cardinality of triple is : ' . $card );
	
	# round the cardinality to an integer
	return int($card + .5 * ($card <=> 0));
}

sub _cardinality_nestedloop {
	my $self	= shift;
	my $pattern	= shift;
	my @triples	= ($pattern->rhs, $pattern->lhs);
	my $size	= $self->_size;
	my $bf		= $pattern->bf;
	my @bf		= split(/,/, $bf);
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	
	my %seen_frees;
	my $card	= 1;
	foreach my $i (0 .. $#bf) {
		my $const	= RDF::Query::Node::Literal->new('');
		my $bf		= $bf[ $i ];
		my $t		= $triples[ $i ];
		my @f		= ($bf =~ m/(\d+)/g);
		my $f		= scalar(@f);
		my $actually_free	= 0;
		foreach my $f (@f) {
			$actually_free++ unless ($seen_frees{ $f });
		}
		@seen_frees{ @f }	= (1) x $f;
		
		if ($f != $actually_free) {
			my $diff	= $f - $actually_free;
			$l->debug("- BGP triple {" . Dumper($t) . "} has $diff variables that will be bound by previous triples.");
		}
		
		my $r		= $actually_free / 3;
		my $tcard	= ($self->_size ** $r);
		$card		*= $tcard;
	}
	$l->debug( 'Cardinality of BGP is : ' . $card );
	
	# round the cardinality to an integer
	return int($card + .5 * ($card <=> 0));
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
