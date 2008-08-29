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

use RDF::Query::Error qw(:try);

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
	$l->debug( 'Computing COST: ' . $plan->sse( {}, '' ) );
	return 2 * $self->cost( $plan->pattern );
}

sub _cost_union {
	my $self	= shift;
	my $plan	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $plan->sse( {}, '' ) );
	return $self->cost( $plan->lhs ) + $self->cost( $plan->rhs );
}

sub _cost_filter {
	my $self	= shift;
	my $plan	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $plan->sse( {}, '' ) );
	return 2 * $self->cost( $plan->pattern );
}

sub _cost_constant {
	my $self	= shift;
	my $pattern		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $pattern->sse( {}, '' ) );
	return $self->_cardinality( $pattern );
}

sub _cost_nestedloop {
	my $self	= shift;
	my $bgp		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $bgp->sse( {}, '' ) );
	return $self->_cardinality( $bgp );
}

sub _cost_pushdownnestedloop {
	my $self	= shift;
	my $bgp		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $bgp->sse( {}, '' ) );
	return $self->_cardinality( $bgp );
}

sub _cost_triple {
	my $self	= shift;
	my $triple	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $triple->sse( {}, '' ) );
	return $self->_cardinality( $triple );
}

sub _cost_quad {
	my $self	= shift;
	my $quad	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	$l->debug( 'Computing COST: ' . $quad->sse( {}, '' ) );
	return $self->_cardinality( $quad );
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

sub _cardinality_quad {
	my $self	= shift;
	my $pattern	= shift;
	my $size	= $self->_size;
	my $bf		= $pattern->bf;
	my $f		= ($bf =~ tr/f//);
	my $r		= $f / 4;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	my $card	= ($self->_size ** $r);
	$l->debug( 'Cardinality of quad is : ' . $card );
	
	# round the cardinality to an integer
	return int($card + .5 * ($card <=> 0));
}

sub _cardinality_filter {
	my $self	= shift;
	my $pattern	= shift;
	return $self->_cardinality( $pattern->pattern );
}

sub _cardinality_service {
	my $self	= shift;
	my $pattern	= shift;
	return $self->_cardinality( $pattern->pattern );	# XXX this isn't really right. it uses the local data to estimate the cardinality of the remote query...
}

sub _cardinality_union {
	my $self	= shift;
	my $pattern	= shift;
	return $self->_cardinality( $pattern->lhs ) + $self->_cardinality( $pattern->rhs );
}

sub _cardinality_nestedloop {
	my $self	= shift;
	my $pattern	= shift;
	my $size	= $self->_size;

	my $cardinality;
	try {
		my @bf		= $pattern->bf;
		my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
		my @triples	= ($pattern->rhs, $pattern->lhs);
		
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
				$l->debug("- NestedLoop triple {" . $t->sse( {}, '' ) . "} has $diff variables that will be bound by previous triples.");
			}
			
			my $r		= $actually_free / 3;
			my $tcard	= ($self->_size ** $r);
			$card		*= $tcard;
		}
		$l->debug( 'Cardinality of BGP is : ' . $card );
		
		# round the cardinality to an integer
		$cardinality	= int($card + .5 * ($card <=> 0)) * 2;	# XXX hack multiplier. need to figure out what the actual cost of this is based on the cardinality of both sides
	} catch RDF::Query::Error::ExecutionError with {
		my $lhs	= $self->_cardinality( $pattern->lhs );
		unless (defined($lhs)) {
			warn "Computing cardinality of LHS of NestedLoop join failed";
			throw RDF::Query::Error::ExecutionError -text => "Computing cardinality of LHS of NestedLoop join failed";
		}
		
		my $rhs	= $self->_cardinality( $pattern->rhs );
		unless (defined($rhs)) {
			warn "Computing cardinality of RHS of NestedLoop join failed";
			throw RDF::Query::Error::ExecutionError -text => "Computing cardinality of RHS of NestedLoop join failed";
		}
		
		$cardinality	= $lhs * $rhs;
	};
	return $cardinality;
}

sub _cardinality_pushdownnestedloop {
	my $self	= shift;
	my $pattern	= shift;
	my @triples	= ($pattern->rhs, $pattern->lhs);
	my $size	= $self->_size;
	
	my $cardinality;
	try {
		my @bf		= $pattern->bf;
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
				$l->debug("- PushDownNestedLoop triple {" . $t->sse( {}, '' ) . "} has $diff variables that will be bound by previous triples.");
			}
			
			my $r		= $actually_free / 3;
			my $tcard	= ($self->_size ** $r);
			$card		*= $tcard;
		}
		$l->debug( 'Cardinality of BGP is : ' . $card );
		
		# round the cardinality to an integer
		$cardinality	= int($card + .5 * ($card <=> 0)) * 1.5;	# XXX hack multiplier. need to figure out what the actual cost of this is based on the cardinality and the overhead of the RHS
	} catch RDF::Query::Error::ExecutionError with {
		my $lhs	= $self->_cardinality( $pattern->lhs );
		unless (defined($lhs)) {
			throw RDF::Query::Error::ExecutionError -text => "Computing cardinality of LHS of PushDownNestedLoop join failed";
		}
		
		my $rhs	= $self->_cardinality( $pattern->rhs );
		unless (defined($rhs)) {
			throw RDF::Query::Error::ExecutionError -text => "Computing cardinality of RHS of PushDownNestedLoop join failed";
		}
		
		$cardinality	= $lhs * $rhs;
	};
	return $cardinality;
}

sub _cardinality_constant {
	my $self	= shift;
	my $pattern	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.costmodel");
	my $card	= $pattern->size;
	$l->trace('Cardinality of Constant is ' . $card);
	return $card;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
