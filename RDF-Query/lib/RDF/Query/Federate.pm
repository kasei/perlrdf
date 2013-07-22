# RDF::Query::Federate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Federate - A subclass of RDF::Query for efficient federated query execution.

=head1 VERSION

This document describes RDF::Query::Federate version 2.910.

=head1 STATUS

This module's API and functionality should be considered deprecated.
If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 SYNOPSIS

 my $service = RDF::Query::ServiceDescription->new( $url );
 my $query = new RDF::Query::Federate ( $sparql );
 $query->add_service( $service );
 my $stream = $query->execute();

=head1 DESCRIPTION

...

=cut

package RDF::Query::Federate;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);

use RDF::Query;
use RDF::Query::Federate::Plan;
use RDF::Query::ServiceDescription;
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION		= '2.910';
}


######################################################################

=head1 METHODS

=over 4

=cut


=item C<< new ( $query, \%options ) >>

=item C<< new ( $query, $base_uri, $languri, $lang ) >>

Returns a new RDF::Query::Federate object for the specified C<$query>.
The query language defaults to SPARQLP, but may be set specifically by
specifying either C<$languri> or C<$lang>, whose acceptable values are:

  $lang: 'rdql', 'sparql11', or 'sparql'

  $languri: 'http://www.w3.org/TR/rdf-sparql-query/', or 'http://jena.hpl.hp.com/2003/07/query/RDQL'

=cut

sub new {
	my $class	= shift;
	my $query	= shift;
	my $base_uri	= shift;
	my $languri	= shift;
	my $lang	= shift || 'sparql11';
	return $class->SUPER::new( $query, $base_uri, $languri, $lang, @_ );
}


=item C<< add_service ( $service_description ) >>

Adds the service described by C<< $service_description >> to the query's list
of data sources.

=cut

sub add_service {
	my $self	= shift;
	my $service	= shift;
	push(@{ $self->{ services } }, $service);
	$self->add_computed_statement_generator( $service->computed_statement_generator );
	
	# and clear out the per-execution query cache, because adding a service might affect the cached values
	$self->{_query_cache}	= {};
	return;
}

=item C<< services >>

=cut

sub services {
	my $self	= shift;
	return @{ $self->{ services } || [] };
}



=item C<< algebra_fixup ( $algebra, $bridge, $base_uri, $ns ) >>

Called in the fixup method of ::Algebra classes, returns either an optimized
::Algebra object ready for execution, or undef (in which case it will be
prepared for execution by the ::Algebra::* class itself.

=cut

sub algebra_fixup {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base_uri	= shift;
	my $ns		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.federate");
	
	$l->trace("RDF::Query::Federate::algebra_fixup called");
	if ($self->{force_no_optimization}) {
		$l->debug("force_no_optimization flag is set, so not performing federation optimization");
		return;
	}
	
	# optimize BGPs when we're using service descriptions for pattern matching
	# (instead of local model-based matching). figure out which triples in the
	# bgp can be sent to which endpoints, and construct appropriate SERVICE
	# algebra objects to use instead of the BGP.
	if ($pattern->isa('RDF::Query::Algebra::BasicGraphPattern')) {
		if ($self->{ service_predicates }) {
			my @patterns	= $self->_services_for_bgp_triples( $pattern, $bridge, $base_uri, $ns );
			my $simple_ggp	= RDF::Query::Algebra::GroupGraphPattern->new( @patterns );
			my @optimized	= $self->_join_services_for_bgp_triples( $pattern, $bridge, $base_uri, $ns, \@patterns );
			
			if ($l->is_debug) {
				foreach my $i (0 .. $#optimized) {
					$l->debug("OPTIMIZED $i:\n" . $optimized[$i]->as_sparql({}, '') . "\n---------------\n");
				}
			}
			
			my @plan		= (@optimized, $simple_ggp);
			while (scalar(@plan) > 1) {
				my $rhs		= pop(@plan);
				my $lhs		= pop(@plan);
				my $union	= RDF::Query::Algebra::Union->new( $lhs, $rhs );
				push(@plan, $union);
			}
			
			my $fixed	= do {
				# turn off optimizations, so we don't end up right back here, trying to optimize this replacement GGP.
				local($self->{force_no_optimization})	= 1;
				my $ggp		= $plan[0];
				$ggp->fixup( $self, $bridge, $base_uri, $ns );
			};
			
			my $bgp	= "\n" . $pattern->as_sparql({}, '');
			$bgp	=~ s/\n/\n\t/g;
			$l->info("replacing BGP =====> {$bgp\n}\n\ WITH =====>\n" . $fixed->as_sparql({}, ''));
			return $fixed;
		}
	}
	return $bridge->fixup( $pattern, $self, $base_uri, $ns );
}


sub _join_services_for_bgp_triples {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base_uri	= shift;
	my $ns		= shift;
	my $simplep	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.federate");
	
	my @join_patterns;		# array of tuples, each containing a service pattern and a list of applicable triples
	foreach my $sd (@{ $self->{services} }) {
		my $patterns	= $sd->patterns;
		foreach my $bgp (@$patterns) {
			push( @join_patterns, [ $bgp, $sd, [], [] ] );
		}
	}
	
	my @triples	= $pattern->triples;
	foreach my $i (0 .. $#triples) {
		my $triple	= $triples[ $i ];
		my $simple	= $simplep->[ $i ];
		
		$l->debug("looking at triple: " . $triple->as_sparql({}, ''));
		
		my @services;
		my $pred	= $triple->predicate;
		if ($pred->isa('RDF::Trine::Node::Variable')) {
			throw RDF::Query::Error::ExecutionError -text => "Cannot use triples with variable predicates with federation endpoints";
		} else {
			foreach my $service_pat (@join_patterns) {
				my ($bgp, $sd)	= @$service_pat;
				if ($bgp->subsumes( $triple )) {
					$l->debug("triple {" . $triple->as_sparql({}, "\t") . "} is subsumed by bgp: {" . $bgp->as_sparql({}, "\t") . "}\n");
					push( @{ $service_pat->[2] }, $triple );
				} else {
					$l->debug("triple {" . $triple->as_sparql({}, "\t") . "} IS NOT subsumed by bgp: {" . $bgp->as_sparql({}, "\t") . "}\n");
					push( @{ $service_pat->[3] }, $simple );
				}
			}
			
		}
	}
	
	my @patterns;
	foreach my $service_pat (@join_patterns) {
		my (undef, $sd, $join_triples, $simple_triples)	= @$service_pat;
		$l->debug("=====> SERVICE <" . $sd->url . ">\n");
		$l->debug(Dumper({ $sd->url => [$join_triples] }));
		my @triples	= @$join_triples;
		
		next unless (scalar(@triples) > 1);
		my $serviceurl	= RDF::Query::Node::Resource->new( $sd->url );
		my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @triples );
		unless ($bgp->connected) {
			$l->debug("BGP isn't connected. Ignoring.");
			next;
		}
		my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( $bgp );
		my $service		= RDF::Query::Algebra::Service->new( $serviceurl, $ggp );
		$l->debug("Triples can be grouped together: \n" . $service->as_sparql( {}, '' ));
		
		my $fullggp		= RDF::Query::Algebra::GroupGraphPattern->new( $service, @$simple_triples );
		push(@patterns, $fullggp);
	}
	return @patterns;
}

sub _services_for_bgp_triples {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base_uri	= shift;
	my $ns		= shift;
	
	my $preds	= $self->{ service_predicates };
	
	my %service_triples;	# arrays of triples, keyed by service urls
	my @service_triples;	# array of tuples each containing a triple and a list of applicable services
	foreach my $triple ($pattern->triples) {
		my @services;
		my $pred	= $triple->predicate;
		if ($pred->isa('RDF::Trine::Node::Variable')) {
			throw RDF::Query::Error::ExecutionError -text => "Cannot use triples with variable predicates with federation endpoints";
		} else {
			my $purl		= $pred->uri_value;
			my $services	= $preds->{ $purl } || [];
			if (scalar(@$services) == 0) {
				throw RDF::Query::Error::ExecutionError -text => "Triple is not described as a capability of any federation endpoint: " . $triple->as_sparql;
			} else {
				foreach my $sd (@$services) {
					push( @{ $service_triples{ $sd->url } }, $triple );
					push( @services, $sd->url );
				}
			}
		}
		push( @service_triples, [ $triple, \@services ] );
	}
	
	my @patterns;
	my %triples_for_single_service;
	foreach my $data (@service_triples) {
		my ($triple, $services)	= @$data;
		my @services	= @$services;
		my @spatterns;
#		if (scalar(@services) == 1) {
#			push( @{ $triples_for_single_service{ $services[0] } }, $triple );
#		} else {
			foreach my $surl (@services) {
				my $serviceurl	= RDF::Query::Node::Resource->new( $surl );
				my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( $triple );
				my $service		= RDF::Query::Algebra::Service->new( $serviceurl, $ggp );
				push(@spatterns, $service);
			}
			while (@spatterns > 1) {
				my @patterns	= splice( @spatterns, 0, 2, () );
				my $union	= RDF::Query::Algebra::Union->new( map { RDF::Query::Algebra::GroupGraphPattern->new($_) } @patterns );
				push(@spatterns, $union );
			}
			my $ggp	= RDF::Query::Algebra::GroupGraphPattern->new( @spatterns );
			push(@patterns, $ggp);
#		}
	}
# 	foreach my $surl (keys %triples_for_single_service) {
# 		my $triples		= $triples_for_single_service{ $surl };
# 		warn "triples for only $surl: " . Dumper($triples) if ($debug);
# 		my $serviceurl	= RDF::Query::Node::Resource->new( $surl );
# 		my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @$triples );
# 		my $service		= RDF::Query::Algebra::Service->new( $serviceurl, $ggp );
# 		unshift(@patterns, $service);
# 	}
	return @patterns;
}

=begin private

=item C<< plan_class >>

Returns the class name for Plan generation. This method should be overloaded by
RDF::Query subclasses if the implementation also provides a subclass of
RDF::Query::Plan.

=end private

=cut

sub plan_class {
	return 'RDF::Query::Federate::Plan';
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
