#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More;

use lib qw(. t);
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	log4perl.category.rdf.query.algebra.service          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $model_tests		= 5;
my $nomodel_tests	= 2;
my $file	= 'data/foaf.xrdf';
my @models	= test_models($file);

eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} elsif (exists $ENV{RDFQUERY_NETWORK_TESTS}) {
	plan tests => scalar(@models) * $model_tests + $nomodel_tests;
} else {
	plan skip_all => 'No network. Set RDFQUERY_DEV_TESTS and set RDFQUERY_NETWORK_TESTS to run these tests.';
	return;
}

use RDF::Query;
use RDF::Query::Logger;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	SKIP: {
		if ($model->isa('RDF::Trine::Model')) {
			skip("RDF::Trine doesn't execute triple patterns (optimized away)", 5);
		}
		
		{
			my $l	= new RDF::Query::Logger;
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql', logger => $l );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?page
				WHERE { ?person foaf:name "Gregory Todd Williams" ; foaf:homepage ?page }
END
			my @results	= $query->execute( $model );
			is( scalar(@results), 1, 'Expected result count' );
			is( $l->{'cardinality-triple'}{'?person <http://xmlns.com/foaf/0.1/homepage> ?page .'}[0], 1, 'Expected triple cardinality' );
			is( $l->{'cardinality-triple'}{'?person <http://xmlns.com/foaf/0.1/name> "Gregory Todd Williams" .'}[0], 1, 'Expected triple cardinality' );
		}
		
		{
			my $l	= new RDF::Query::Logger;
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql', logger => $l );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?p
				WHERE { ?p a foaf:Person }
END
			my @results	= $query->execute( $model );
			is( scalar(@results), 4, 'Expected result count' );
			is( $l->{'cardinality-triple'}{'?p a <http://xmlns.com/foaf/0.1/Person> .'}[0], 4, 'Expected triple cardinality' );
		}
	}
}

{
	print "# SERVICE call\n";
	my $l	= new RDF::Query::Logger;
	my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		SELECT DISTINCT *
		WHERE {
			SERVICE <http://kasei.us/sparql> {
				<http://kasei.us/pictures/2006/20060612-ESWC/images/DSC_2290.jpg>
					foaf:depicts [ foaf:name ?name ]
			}
		}
END
	my @results	= $query->execute();
	is( scalar(@results), 1, 'Got one result' );
	my $d	= shift(@results);
	isa_ok( $d, 'HASH' );
	use Data::Dumper;
	warn Dumper($l);
}


{
	print "# SERVICE call\n";
	my $l	= new RDF::Query::Logger;
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT * WHERE { SERVICE <http://kasei.us/sparql> { ?p a foaf:Person } }
END
		my @results	= $query->execute();
	}
	{
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp', logger => $l );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT * WHERE { SERVICE <http://kasei.us/sparql> { ?s a foaf:Image } }
END
		my @results	= $query->execute();
	}
	warn Dumper([ keys %$l ]);
	my ($a,$s)	= $l->get_statistics( 'cardinality-bf-service-http://kasei.us/sparql', '1bb' );
	warn Dumper($a, $s);
}


