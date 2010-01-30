# RDF::Query::BGPOptimizer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::BGPOptimizer - Optimizer for ordering the joins of triple patterns in a BGP

=head1 VERSION

This document describes RDF::Query::BGPOptimizer version 2.201, released 30 January 2010.

=head1 METHODS

=over 4

=cut

package RDF::Query::BGPOptimizer;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);
use Scalar::Util qw(blessed reftype refaddr);
use RDF::Query::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.201';
}

######################################################################

=item C<< ordered_triples ( $context, @triples ) >>

Returns a list of triples, ordered so as to optimize a left-deep join plan based
on the frequency counts provided by the underlying model.

=cut

sub ordered_triples {
	my $self	= shift;
	my $context	= shift;
	my @triples	= @_;
	
	my $model	= $context->model;
	my $cm		= $context->costmodel;
	
	unless (blessed($cm)) {
		throw RDF::Query::Error::ExecutionError -text => "No CostModel object found in ExecutionContext during BGPOptimizer call";
	}
	
	my %vars;
	my %seen;
	my @weighted	= map {
		my $triple		= RDF::Query::Plan::Triple->new( $_->nodes );
		[ $_, $cm->cost( $triple, $context ) ]
	} @triples;
	my %triples		= map { refaddr($_->[0]) => $_ } @weighted;
	my @ordered	= sort { $a->[1] <=> $b->[1] } @weighted;
	
	foreach my $t (@triples) {
		my @vars		= $self->_triple_vars( $t );
		foreach my $name (@vars) {
			push( @{ $vars{ $name } }, $t ) unless ($seen{ $name }{ refaddr($t) }++);
		}
	}
	
	my %edges;
	foreach my $name (keys %vars) {
		my @triples	= @{ $vars{ $name } };
		foreach my $t (@triples) {
			my $ta	= refaddr($t);
			foreach my $u (@triples) {
				my $ua	= refaddr($u);
				next if ($ta == $ua);
				$edges{ $ta }{ $ua }	= $u;
			}
		}
	}
	
	
	my @final;
	my %used;
	my $start	= shift(@ordered);
	$used{ refaddr($start) }++;
	push(@final, $start);
	
	my @seen	= refaddr($start->[0]);
	my $count	= 0;
	while (@ordered) {
		if (++$count > scalar(@triples)) {
			die "loop in BGPOptimizer (?)";
		}
		
		my @frontier	= grep { not($used{refaddr($_)}) } map { $triples{ $_ } } map { keys(%{ $edges{ $_ } }) } @seen;
		my @orderedf	= sort { $a->[1] <=> $b->[1] } @frontier;
		if (@orderedf) {
			my $next	= shift(@orderedf);
			my $addr	= refaddr($next);
			$used{ $addr }++;
			push(@final, $next);
			push(@seen, refaddr($next->[0]));
			@ordered	= grep { refaddr($_) != $addr } @ordered;
		} else {
			my $next	= shift(@ordered);
			my $addr	= refaddr($next);
			$used{ $addr }++;
			push(@final, $next);
			push(@seen, refaddr($next->[0]));
		}
	}
	
	return map { $_->[0] } @final;
}

sub _triple_vars {
	my $self	= shift;
	my $t		= shift;
	my @nodes	= $t->nodes;
	my (@vars, %seen);
	foreach my $n (@nodes) {
		if ($n->isa('RDF::Trine::Node::Variable')) {
			my $name	= $n->name;
			push(@vars, $name) unless ($seen{ $name }++);
		}
	}
	return @vars;
}


# 	
# 	my @plans;
# 	my @triples	= map { $_->[0] } sort { $b->[1] <=> $a->[1] } map { [ $_, $model->node_count( $_->nodes ) ] } @$triples;
# 	
# 	my $t	= shift(@triples);
# 	my @lhs_plans	= map { [ $_, [$t] ] } $self->generate_plans( $t, $context, %args );
# 	if (@triples) {
# 		my @rhs_plans	= $self->_triple_join_plans_opt( $context, \@triples, %args );
# 		foreach my $i (0 .. $#lhs_plans) {
# 			foreach my $j (0 .. $#rhs_plans) {
# 				my $a			= $lhs_plans[ $i ][0];
# 				my $b			= $rhs_plans[ $j ][0];
# 				my $algebra_a	= $lhs_plans[ $i ][1];
# 				my $algebra_b	= $rhs_plans[ $j ][1];
# #				foreach my $join_type (@join_types) {
# 					try {
# 						my @algebras	= (@$algebra_a, @$algebra_b);
# 						my %logging_keys;
# 						if ($method eq 'triples') {
# 							my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @algebras );
# 							my $sparql		= $bgp->as_sparql;
# 							my $bf			= $bgp->bf;
# 							$logging_keys{ bf }		= $bf;
# 							$logging_keys{ sparql }	= $sparql;
# 						} else {
# 							my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @algebras );
# 							my $sparql		= $ggp->as_sparql;
# 							$logging_keys{ sparql }	= $sparql;
# 						}
# #						my $plan	= $join_type->new( $b, $a, 0, \%logging_keys );
# 						my $plan	= RDF::Query::Plan::Join::NestedLoop->new( $b, $a, 0, \%logging_keys );
# 						push( @plans, [ $plan, [ @algebras ] ] );
# 					} catch RDF::Query::Error::MethodInvocationError with {
# 		#				warn "caught MethodInvocationError.";
# 					};
# #				}
# 			}
# 		}
# 	} else {
# 		@plans	= @lhs_plans;
# 	}
# 	
# 	return @plans;

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
