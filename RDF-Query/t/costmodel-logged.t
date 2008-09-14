#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More tests => 7;

use lib qw(. t);
BEGIN { require "models.pl"; }

use RDF::Query;
use RDF::Query::Logger;
use RDF::Query::CostModel::Logged;
use RDF::Trine::Namespace qw(rdf foaf);

use Data::Dumper;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel		= TRACE, Screen
# 	log4perl.category.rdf.query.plan.triple		= TRACE, Screen
# 	log4perl.appender.Screen					= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr				= 0
# 	log4perl.appender.Screen.layout				= Log::Log4perl::Layout::SimpleLayout
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
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT * WHERE { ?p foaf:name ?name }
END
		my @results	= $query->execute( $model );
		# should populate:
		#	cardinality-bf-triple	1b2											=> 6
		#	cardinality-triple		?p <http://xmlns.com/foaf/0.1/name> ?name .	=> 6
	}
}
################################################################################


{
	my $costmodel	= RDF::Query::CostModel::Logged->new();
	isa_ok( $costmodel, 'RDF::Query::CostModel' );
}

my $context	= RDF::Query::ExecutionContext->new(
				bound	=> {},
			);
my $costmodel	= RDF::Query::CostModel::Logged->new( $l );

{
	# COST OF TRIPLE
	{
		# <p> a foaf:Person
		my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Resource->new('p'), $rdf->type, $foaf->Person, { bf => 'bbb' });
		my $cost		= $costmodel->cost( $triple, $context );
		is( $cost, 1, 'Cost of 3-bound triple' );
	}
	
	{
		# ?p a foaf:Person
		my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, { bf => '1bb' } );
		my $cost		= $costmodel->cost( $triple, $context );
		is( $cost, 4, 'Cost of 2-bound triple' );
	}
	
	{
		# ?p a ?type
		my $triple		= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, RDF::Trine::Node::Variable->new('type'), { bf => '1b2' } );
		my $cost		= $costmodel->cost( $triple, $context );
		is( $cost, 1.6, 'Cost of 1-bound triple' );
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
		is( $cost, 10_005.6, 'Cost of a 1bb,1b2 BGP' );
	}
	
	{
		# { ?p a foaf:Person ; foaf:name ?name }
		my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person, );
		my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name'), );
		my $bgp			= RDF::Query::Plan::Join::PushDownNestedLoop->new( $triple_a, $triple_b );
		# this should really be 10 * 10, since the binding of ?p will hopefully propagate to the second triple pattern (but this isn't done in the current implementation)
		my $cost		= $costmodel->cost( $bgp, $context );
		is( $cost, 404, 'Cost of a 1bb,1b2 BGP (push down)' );
	}
	
	{
		# { ?a a foaf:Person . ?b a foaf:Person }
		my $triple_a	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('a'), $rdf->type, $foaf->Person, );
		my $triple_b	= RDF::Query::Plan::Triple->new( RDF::Trine::Node::Variable->new('b'), $rdf->type, $foaf->Person, );
		my $bgp			= RDF::Query::Plan::Join::NestedLoop->new( $triple_a, $triple_b );
		# 10 * 10
		my $cost		= $costmodel->cost( $bgp, $context );
		is( $cost, 10_008, 'Cost of a 1bb,2bb BGP' );
	}
}

