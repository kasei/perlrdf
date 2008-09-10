#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More tests => 9;

use lib qw(. t);
BEGIN { require "models.pl"; }

use RDF::Query;
use RDF::Query::CostModel::Naive;
use RDF::Trine::Namespace qw(rdf foaf);

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

{
	my $costmodel	= RDF::Query::CostModel::Naive->new();
	isa_ok( $costmodel, 'RDF::Query::CostModel' );
}

my $context	= RDF::Query::ExecutionContext->new(
				bound	=> {},
			);
for my $size (1_000) {
	my $costmodel	= RDF::Query::CostModel::Naive->new( size => $size );
	
	{
		# COST OF TRIPLE
		{
			# <p> a foaf:Person
			my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Resource->new('p'), $rdf->type, $foaf->Person, );
			my $cost		= $costmodel->cost( $triple, $context );
			is( $cost, 1, 'Cost of 3-bound triple' );
		}
		
		{
			# ?p a foaf:Person
			my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
			my $cost		= $costmodel->cost( $triple, $context );
			is( $cost, 10, 'Cost of 2-bound triple' );
		}
		
		{
			# ?p a ?type
			my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, RDF::Trine::Node::Variable->new('type'), );
			my $cost		= $costmodel->cost( $triple, $context );
			is( $cost, 100, 'Cost of 1-bound triple' );
		}
	}

	{
		# COST OF BGP
		{
			# { ?p a foaf:Person ; foaf:name ?name }
			my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
			my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name'), );
			my $bgp			= RDF::Query::Plan::Join::NestedLoop->new( $triple_a, $triple_b );
			# this should really be 10 * 10, since the binding of ?p will hopefully propagate to the second triple pattern (but this isn't done in the current implementation)
			my $cost		= $costmodel->cost( $bgp, $context );
			is( $cost, 210, 'Cost of a 1bb,1b2 BGP' );
		}
		
		{
			# push down
			# { ?p a foaf:Person ; foaf:name ?name }
			my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
			my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name'), );
			my $bgp			= RDF::Query::Plan::Join::PushDownNestedLoop->new( $triple_a, $triple_b );
			# this should really be 10 * 10, since the binding of ?p will hopefully propagate to the second triple pattern (but this isn't done in the current implementation)
			my $cost		= $costmodel->cost( $bgp, $context );
			is( $cost, 20, 'Cost of a 1bb,1b2 BGP' );
		}
		
		{
			# { ?a a foaf:Person . ?b a foaf:Person }
			my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('a'), $rdf->type, $foaf->Person, );
			my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('b'), $rdf->type, $foaf->Person, );
			my $bgp			= RDF::Query::Plan::Join::NestedLoop->new( $triple_a, $triple_b );
			my $cost		= $costmodel->cost( $bgp, $context );
			is( $cost, 120, 'Cost of a 1bb,2bb BGP' );
		}
	}
	
	{
		# COST OF SERVICE
		{
			# { ?p a foaf:Person ; foaf:name ?name }
			my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
			my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name'), );
			my $bgp			= RDF::Query::Plan::Join::NestedLoop->new( $triple_a, $triple_b );
			my $service		= RDF::Query::Plan::Service->new( 'http://kasei.us/sparql', $bgp, 'SELECT * WHERE { ?p a foaf:Person ; foaf:name ?name }' );
			my $cost		= $costmodel->cost( $service, $context );
			is( $cost, 310, 'Cost of a 1bb,1b2 SERVICE' );
		}
		
		{
			# Pushdown Nested Loop
			# { ?p a foaf:Person ; foaf:name ?name }
			my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
			my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name'), );
			my $bgp			= RDF::Query::Plan::Join::PushDownNestedLoop->new( $triple_a, $triple_b );
			my $service		= RDF::Query::Plan::Service->new( 'http://kasei.us/sparql', $bgp, 'SELECT * WHERE { ?p a foaf:Person ; foaf:name ?name }' );
			my $cost		= $costmodel->cost( $service, $context );
			is( $cost, 120, 'Cost of a 1bb,1b2 SERVICE (push down)' );
		}
	}
}

