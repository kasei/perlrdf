#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More tests => 6;

use lib qw(. t);
BEGIN { require "models.pl"; }

use RDF::Query;
use RDF::Query::CostModel::Naive;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $parser	= RDF::Query::Parser::SPARQL->new();
my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };

{
	my $costmodel	= RDF::Query::CostModel::Naive->new();
	isa_ok( $costmodel, 'RDF::Query::CostModel' );
}

for my $size (1_000) {
	my $costmodel	= RDF::Query::CostModel::Naive->new( size => $size );
	
	{
		# COST OF TRIPLE
		{
			my ($bgp)		= $parser->parse_pattern('{ <p> a foaf:Person }', undef, $ns)->patterns;
			my ($triple)	= ($bgp->triples);
			my $cost		= $costmodel->cost( $triple );
			is( $cost, 1, 'Cost of all-bound triple' );
		}
		
		{
			my ($bgp)		= $parser->parse_pattern('{ ?p a foaf:Person }', undef, $ns)->patterns;
			my ($triple)	= ($bgp->triples);
			my $cost		= $costmodel->cost( $triple );
			is( $cost, 10, 'Cost of 2-bound triple' );
		}
		
		{
			my ($bgp)		= $parser->parse_pattern('{ ?p a ?type }', undef, $ns)->patterns;
			my ($triple)	= ($bgp->triples);
			my $cost		= $costmodel->cost( $triple );
			is( $cost, 100, 'Cost of 1-bound triple' );
		}
	}


	{
		# COST OF BGP
		{
			my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
			# this should really be 10 * 10, since the binding of ?p will hopefully propagate to the second triple pattern (but this isn't done in the current implementation)
			my $cost		= $costmodel->cost( $bgp );
			is( $cost, 100, 'Cost of a 1bb,1b2 BGP' );
		}
		
		{
			my ($bgp)	= $parser->parse_pattern('{ ?a a foaf:Person . ?b a foaf:Person }', undef, $ns)->patterns;
			# 10 * 10
			my $cost		= $costmodel->cost( $bgp );
			is( $cost, 100, 'Cost of a 1bb,2bb BGP' );
		}
	}
}

