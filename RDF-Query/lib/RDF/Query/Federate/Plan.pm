# RDF::Query::Federate::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Federate::Plan - Executable query plan nodes.

=head1 VERSION

This document describes RDF::Query::Federate::Plan version 2.918.

=head1 STATUS

This module's API and functionality should be considered deprecated.
If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 METHODS

=over 4

=cut

package RDF::Query::Federate::Plan;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Data::Dumper;
use Set::Scalar;
use List::Util qw(reduce);
use Scalar::Util qw(blessed refaddr);
use RDF::Query::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

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
		my $aclass	= ref($algebra);
		my ($type)	= ($aclass =~ m<::(\w+)$>);
		
		if ($type eq 'BasicGraphPattern') {
# 			my ($plan)	= $self->prune_plans( $context, $self->SUPER::generate_plans( $algebra, $context, %args ) );
			my ($plan)	= $self->SUPER::generate_plans( $algebra, $context, %args );
			my @triples	= $algebra->triples();
			my @fplans	= map { $_->[0] } $self->_optimistic_triple_join_plans( $context, \@triples, %args, method => 'triples' );
			$l->debug("generating plans for federated query with algebra: $sse");
			my @optimistic_plans;
#			foreach my $plan (@plans) {
				if (@fplans) {
					my $time	= $context->optimistic_threshold_time || 0;
					my $oplan	= RDF::Query::Plan::ThresholdUnion->new( $time, @fplans, $plan );
					$oplan->label( services => $plan->label( 'services' ) );
					push(@optimistic_plans, $oplan);
				}
				unless (@optimistic_plans) {
					push(@optimistic_plans, $plan);
				}
#			}
			
			$cache->{ $sse }	= \@optimistic_plans;
			if ($l->is_debug) {
				foreach my $i (0 .. $#optimistic_plans) {
					my $p	= $optimistic_plans[ $i ];
					my $sse	= $p->sse({}, '');
					$l->debug("optimistic plan $i: $sse");
				}
			}
			return @optimistic_plans;
		} else {
			return $self->SUPER::generate_plans( $algebra, $context, %args );
		}
	}
}

sub _optimistic_triple_join_plans {
	my $self	= shift;
	my $context	= shift;
	my $triples	= shift;
	my %args	= @_;
	my $l		= Log::Log4perl->get_logger('rdf.query.federate.plan');
	
	my $method		= $args{ method };
	my @join_types	= RDF::Query::Plan::Join->join_classes;
	my @triples		= @$triples;
	my %triples		= map { refaddr($_) => $_ } @triples;
	my %ids			= map { refaddr($triples[$_]) => $_ } (0 .. $#triples);
	my %tplans		= map { refaddr($_) => [ $self->generate_plans( $_, $context, %args ) ] } @triples;
	
	my %per_service;
	my @service_plans;
	foreach my $id (0 .. $#triples) {
		my $r	= refaddr($triples[$id]);
		my $ps	= $tplans{$r};
		my $t	= $triples{ $r };
		foreach my $pid (0 .. $#{ $ps }) {
			my $p	= $ps->[ $pid ];
			$self->label_plan_with_services( $p, $context );
			push(@service_plans, { plan => $p, size => 1, coverage => [$id] });
			foreach my $service (@{ $p->label('services') || [] }) {
				push( @{ $per_service{ $service }{ $r } }, $p );
			}
		}
	}
	
	foreach my $s (sort keys %per_service) {
		$l->trace("SERVICE: $s");
		my $data	= $per_service{ $s };
		my @triples;
		my @ids;
		foreach my $r (sort { $ids{ $a } <=> $ids{ $b } } keys %$data) {
			my $t	= $triples{ $r };
			push(@ids, $ids{ $r });
			push(@triples, $t);
			$l->trace("\tTRIPLE $ids{$r}: " . $t->sse);
			my @plans	= @{ $data->{ $r } };
			foreach my $p (@plans) {
				$l->trace("\t\tPLAN: " . $p->sse);
			}
		}
		my ($join)	= $self->_triple_join_plans( $context, \@triples, %args );
		my ($plan, $algebras)	= @$join;
		my $size	= scalar(@$algebras);
		my $algebra	= ($size > 1) ? RDF::Query::Algebra::BasicGraphPattern->new( @$algebras ) : $algebras->[0];
		$plan->label('algebra', $algebra);
		my $service	= RDF::Query::Plan::Service->new_from_plan( $s, $plan, $context );
		push(@service_plans, { service => $s, plan => $service, size => $size, coverage => [sort { $a <=> $b } @ids] });
	}
	
	my %plans_by_coverage;
	foreach my $sp (@service_plans) {
		my @cover	= @{ $sp->{ coverage } };
		my $data	= \%plans_by_coverage;
		while (@cover) {
			my $c	= shift(@cover);
			$data	= ($data->{ $c } ||= {});
		}
		$data->{ '_service' }	= $sp;
	}
	
	my @plans;
	my $full_coverage	= join('', 0..$#triples);
	my @join_service_plans	= sort { $b->{size} <=> $a->{size} } grep { $_->{size} >= 2 } @service_plans;
SP:	foreach my $sp (@join_service_plans) {
		$l->trace("----------------------->");
		my $plan		= $sp->{plan};
		my $coverage	= join('', @{$sp->{coverage}});
		$l->trace("trying service $sp->{service} with BGP coverage $coverage");
		while ($coverage ne $full_coverage) {
			$l->trace("coverage ($coverage) isn't full yet (needs to be $full_coverage)");
			my $needed	= $full_coverage;
			foreach my $c (split(//, $coverage)) {
				$needed	=~ s/$c//;
			}
			my @needed	= split('', $needed);
			
			# XXX this is where things go naive. ideally, we would start with
			# XXX any triple that yielded the optimal bin packing of plans to
			# XXX produce full coverage, but instead we start with the lowest
			# XXX numbered triple, and use a greedy search from there.
			my $start	= shift(@needed);
			$l->trace("starting remote BGP with triple $start");
			$coverage	.= $start;
			my $access_key	= $start;
			my $data	= $plans_by_coverage{ $start };
			while (@needed and ref($data->{ $needed[0] })) {
				my $c	= shift(@needed);
				$access_key	.= $c;
				$l->trace("adding triple $c to the current remote BGP");
				$coverage	.= $c;
				$data	= $data->{ $c };
			}
			unless (exists $data->{ '_service' }) {
				$l->trace("the current plan reached a dead end with key '$access_key': " . Dumper($data));
				next SP;
			}
			$l->trace("no more triples in this remote BGP");
			my $join_plan	= $data->{ '_service' }{'plan'};
			Carp::confess Dumper($full_coverage, $coverage, $data) unless ref($join_plan);
			$plan	= RDF::Query::Plan::Join::NestedLoop->new( $plan, $join_plan, 0, {} );
			$coverage	= join('', sort split(//, $coverage));
		}
		push(@plans, $plan);
		$l->trace("<-------------");
	}
	if (@plans) {
		my $count	= scalar(@plans);
		$l->debug("returning $count possible QEPs for optimistic BGP");
		return map {[$_, $triples]} @plans;
	} else {
		return;
	}
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

=head1 COPYRIGHT

Copyright (c) 2005-2009 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
