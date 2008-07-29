#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More tests => 6;

use lib qw(. t);
BEGIN { require "models.pl"; }

use RDF::Query;
use RDF::Query::Logger;
use RDF::Query::CostModel::Logged;

use Data::Dumper;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################



################################################################################
################################################################################
### Fill up the logger with some statistics
my @files	= map { "data/$_" } qw(foaf.xrdf about.xrdf);
my @models	= test_models( @files );

my $l	= new RDF::Query::Logger;
foreach my $model (@models) {
# 	print "\n#################################\n";
# 	print "### Using model: $model\n\n";
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT * WHERE { ?p a foaf:Person }
END
		my @results	= $query->execute( $model );
		# should populate:
		#	cardinality-bf-triple	1bb											=> 4
		#	cardinality-triple		?p a <http://xmlns.com/foaf/0.1/Person> .	=> 4
	}
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT * WHERE { ?p a foaf:Person ; foaf:homepage ?page }
END
		my @results	= $query->execute( $model );
		# should populate:
		#	cardinality-bf-bgp		1bb,1b2										=> 2
		#	cardinality-bgp			?p a <http://xmlns.com/foaf/0.1/Person> . ?p <http://xmlns.com/foaf/0.1/homepage> ?page .	=> 0.5
		
		# the 0.5 comes from the fact that the foaf:homepage triple pattern is executed second,
		# and with ?p pushed down as an SARG, it won't always find a match (since not everyone
		# has a foaf:hoempage property). 4 people with only 2 homepages => E(0.5)
	}
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT * WHERE { ?s a foaf:Image }
END
		my @results	= $query->execute( $model );
		# should populate:
		#	cardinality-bf-triple	1bb											=> 4
		#	cardinality-triple		?s a <http://xmlns.com/foaf/0.1/Image> .	=> 4
	}
}
################################################################################
	

my $parser	= RDF::Query::Parser::SPARQL->new();
my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };

{
	my $costmodel	= RDF::Query::CostModel::Logged->new();
	isa_ok( $costmodel, 'RDF::Query::CostModel' );
}

my $costmodel	= RDF::Query::CostModel::Logged->new( $l );

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
		is( $cost, 4, 'Cost of 2-bound triple' );
	}
	
	{
		my ($bgp)		= $parser->parse_pattern('{ ?p a ?type }', undef, $ns)->patterns;
		my ($triple)	= ($bgp->triples);
		my $cost		= $costmodel->cost( $triple );
		is( $cost, 0.5, 'Cost of 1-bound triple' );
	}
}


{
	# COST OF BGP
	{
		my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
		# this should really be 10 * 10, since the binding of ?p will hopefully propagate to the second triple pattern (but this isn't done in the current implementation)
		my $cost		= $costmodel->cost( $bgp );
		is( $cost, 2, 'Cost of a 1bb,1b2 BGP' );
	}
	
	{
		my ($bgp)	= $parser->parse_pattern('{ ?a a foaf:Person . ?b a foaf:Person }', undef, $ns)->patterns;
		# 10 * 10
		my $cost		= $costmodel->cost( $bgp );
		is( $cost, 10_000, 'Cost of a 1bb,2bb BGP' );	# 10_000 is the fallback value from the naive costmodel (since we didn't fill the logger with data from a cartesian product query like this one)
	}
}

