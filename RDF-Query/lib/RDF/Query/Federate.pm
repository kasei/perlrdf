# RDF::Query::Federate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Federate - A subclass of RDF::Query for efficient federated query execution.

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
use Scalar::Util qw(blessed);
use RDF::Query::ServiceDescription;
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug			= DEBUG;
	$VERSION		= '2.000';
}


######################################################################

=head1 METHODS

=over 4

=item C<< algebra_fixup ( $algebra, $bridge, $base, $ns ) >>

Called in the fixup method of ::Algebra classes, returns either an optimized
::Algebra object ready for execution, or undef (in which case it will be
prepared for execution by the ::Algebra::* class itself.

=cut

sub algebra_fixup {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	return if ($self->{force_no_optimization});
	
	# optimize BGPs when we're using service descriptions for pattern matching
	# (instead of local model-based matching). figure out which triples in the
	# bgp can be sent to which endpoints, and construct appropriate SERVICE
	# algebra objects to use instead of the BGP.
	if ($pattern->isa('RDF::Query::Algebra::BasicGraphPattern')) {
		if ($self->{ service_predicates }) {
			my @patterns	= $self->_services_for_bgp_triples( $pattern, $bridge, $base, $ns );
			my $simple_ggp	= RDF::Query::Algebra::GroupGraphPattern->new( @patterns );
			my @optimized	= $self->_join_services_for_bgp_triples( $pattern, $bridge, $base, $ns, \@patterns );
			
			if ($debug) {
				foreach my $i (0 .. $#optimized) {
					warn "OPTIMIZED $i:\n" . $optimized[$i]->as_sparql({}, '') . "\n---------------\n";
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
				$ggp->fixup( $self, $bridge, $base, $ns );
			};
			
			my $bgp	= "\n" . $pattern->as_sparql({}, '');
			$bgp	=~ s/\n/\n\t/g;
			warn "replacing BGP =====> {$bgp\n}\n\ WITH =====>\n" . $fixed->as_sparql({}, '') if ($debug);
			return $fixed;
		}
	}
	return $bridge->fixup( $pattern, $self, $base, $ns );
}


sub _join_services_for_bgp_triples {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	my $simplep	= shift;
	
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
		
		warn "looking at triple: " . $triple->as_sparql({}, '') if ($debug);
		
		my @services;
		my $pred	= $triple->predicate;
		if ($pred->isa('RDF::Trine::Node::Variable')) {
			throw RDF::Query::Error::ExecutionError -text => "Cannot use triples with variable predicates with federation endpoints";
		} else {
			foreach my $service_pat (@join_patterns) {
				my ($bgp, $sd)	= @$service_pat;
				if ($bgp->subsumes( $triple )) {
					warn "triple {" . $triple->as_sparql({}, "\t") . "} is subsumed by bgp: {" . $bgp->as_sparql({}, "\t") . "}\n" if ($debug);
					push( @{ $service_pat->[2] }, $triple );
				} else {
					warn "triple {" . $triple->as_sparql({}, "\t") . "} IS NOT subsumed by bgp: {" . $bgp->as_sparql({}, "\t") . "}\n" if ($debug);
					push( @{ $service_pat->[3] }, $simple );
				}
			}
			
		}
	}
	
	my @patterns;
	foreach my $service_pat (@join_patterns) {
		my (undef, $sd, $join_triples, $simple_triples)	= @$service_pat;
		warn "=====> SERVICE <" . $sd->url . ">\n" if ($debug);
		warn Dumper({ $sd->url => [$join_triples] }) if ($debug);
		my @triples	= @$join_triples;
		
		next unless (scalar(@triples) > 1);
		my $serviceurl	= RDF::Query::Node::Resource->new( $sd->url );
		my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @triples );
		unless ($bgp->connected) {
			warn "BGP isn't connected. Ignoring." if ($debug);
			next;
		}
		my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( $bgp );
		my $service		= RDF::Query::Algebra::Service->new( $serviceurl, $ggp );
		warn "Triples can be grouped together: \n" . $service->as_sparql( {}, '' ) if ($debug);
		
		my $fullggp		= RDF::Query::Algebra::GroupGraphPattern->new( $service, @$simple_triples );
		push(@patterns, $fullggp);
	}
	return @patterns;
}

sub _services_for_bgp_triples {
	my $self	= shift;
	my $pattern	= shift;
	my $bridge	= shift;
	my $base	= shift;
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


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
