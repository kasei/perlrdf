# RDF::Query::Federate::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Federate::Plan - Executable query plan nodes.

=head1 METHODS

=over 4

=cut

package RDF::Query::Federate::Plan;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use RDF::Query::Error qw(:try);

=item C<< generate_plans ( $algebra, $execution_context, %args ) >>

Returns a list of equivalent query plan objects for the given algebra object.

=cut

sub generate_plans {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my $algebra	= shift;
	my $context	= shift;
	my %args	= @_;
	my $l		= Log::Log4perl->get_logger('rdf.query.federate.plan');
	
	my $query	= $context->query;
	my $cache	= ($query->{_query_cache}{federate_plans} ||= {});
	my $sse	= $algebra->sse();
	
	if ($cache->{ $sse }) {
		return @{ $cache->{ $sse } };
	} else {
		$l->debug("generating plans for federated query with algebra: $sse");
		my @optimistic_plans;
		my @plans	= $self->SUPER::generate_plans( $algebra, $context, %args );
		foreach my $plan (@plans) {
			$self->label_plan_with_services( $plan, $context );
			if (not($plan->isa('RDF::Query::Plan::Triple')) and not($plan->isa('RDF::Query::Plan::ThresholdUnion'))) {
				my @fplans	= $self->optimistic_plans( $plan, $context );
				if (@fplans > 1) {
					my $time	= $context->optimistic_threshold_time;
					my $oplan	= RDF::Query::Plan::ThresholdUnion->new( $time, @fplans, $plan );
					$oplan->label( services => $plan->label( 'services' ) );
					push(@optimistic_plans, $oplan);
				}
			}
			unless (@optimistic_plans) {
				push(@optimistic_plans, $plan);
			}
		}
		
		$cache->{ $sse }	= \@optimistic_plans;
		return @optimistic_plans;
	}
}

=item C<< optimistic_plans ( $plan, $context ) >>

Returns a set of optimistic query plans that may be used to provide subsets of
the results expected from $plan. This method only makes the root node of $plan
optimistic, assuming that it has been called previously for the sub-nodes.

=cut

sub optimistic_plans {
	my $self	= shift;
	my $plan	= shift;
	my $context	= shift;
	my $servs	= $plan->label( 'services' );
	
	my @opt_plans;
	if (ref($servs) and scalar(@$servs)) {
		foreach my $url (@$servs) {
			my $service	= RDF::Query::Plan::Service->new_from_plan( $url, $plan, $context );
			push(@opt_plans, $service);
		}
		unless (@opt_plans) {
			warn "no optimistic plans found for plan " . $plan->sse({}, '');
		}
	}
	return @opt_plans;
}

=item C<< label_plan_with_services ( $plan, $context ) >>

Labels the supplied plan object with the URIs of applicable services that are
capable of answering the query represented by the plan.

=cut

sub label_plan_with_services {
	my $self	= shift;
	my $plan	= shift;
	my $context	= shift;
	my $query	= $context->query;
	my @sds		= $query->services;
	my $l		= Log::Log4perl->get_logger('rdf.query.federate.plan');
	
	if ($plan->isa('RDF::Query::Plan::Triple')) {
		my @services;
		foreach my $sd (@sds) {
			if ($sd->answers_triple_pattern( $plan->triple )) {
				push(@services, $sd);
			}
		}
		
		# $plan might have already been labeled with services, in which case
		# we should just assume the existing label is correct, and save ourselves
		# the work of re-labeling
		if (@services and not($plan->label( 'services' ))) {
			if ($l->is_debug) {
				$l->debug( "SERVICES that can handle pattern: " . $plan->triple->sse . "\n\t" . join("\n\t", map { $_->url } @services) );
			}
			$plan->label( services => [ map { $_->url } @services ] );
		}
	} elsif ($plan->isa('RDF::Query::Plan::Join')) {
		$self->label_plan_with_services($_, $context) for ($plan->lhs, $plan->rhs);
		my $lhs	= $plan->lhs->label( 'services' ) || [];
		my $rhs	= $plan->rhs->label( 'services' ) || [];
		my $set	= Set::Scalar->new(@$lhs)->intersection(Set::Scalar->new(@$rhs));
		if (my @members = $set->members) {
			$plan->label( services => [ @members ] );
		}
	} elsif ($plan->isa('RDF::Query::Plan::ThresholdUnion')) {
		my $dplan	= $plan->default;
		$self->label_plan_with_services($dplan, $context);
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
