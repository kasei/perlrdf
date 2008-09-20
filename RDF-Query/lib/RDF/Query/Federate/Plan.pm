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
	
	my @optimistic_plans;
	my @plans	= $self->SUPER::generate_plans( $algebra, $context, %args );
	foreach my $plan (@plans) {
		$self->label_plan_with_services( $plan, $context );
		push(@optimistic_plans, $plan);
		if ($plan->isa('RDF::Query::Plan::Triple')) {
		} else {
			my @fplans	= $self->optimistic_plan( $plan, $context );
			if (@fplans) {
				my $oplan	= RDF::Query::Plan::ThresholdUnion->new( @fplans, $plan );
				$oplan->label( services => $plan->label( 'services' ) );
				push(@optimistic_plans, $oplan);
			}
		}
	}
	
	return @optimistic_plans;
}

=item C<< optimistic_plan ( $plan, $context ) >>

Returns a set of optimistic query plans that may be used to provide subsets of
the results expected from $plan. This method only makes the root node of $plan
optimistic, assuming that it has been called previously for the sub-nodes.

=cut

sub optimistic_plan {
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
	my @l		= map { Log::Log4perl->get_logger($_) } qw(rdf.query.federate.plan rdf.query.plan);
	
	if ($plan->isa('RDF::Query::Plan::Triple')) {
		my @services;
		foreach my $sd (@sds) {
			if ($sd->answers_triple_pattern( $plan->triple )) {
				push(@services, $sd);
			}
		}
		
		if (@services) {
			$_->debug( "SERVICES that can handle pattern: " . $plan->triple->sse . "\n\t" . join("\n\t", map { $_->url } @services) ) for (@l);
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
