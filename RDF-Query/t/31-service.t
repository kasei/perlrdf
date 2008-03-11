#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
BEGIN { require "models.pl"; }

my $tests	= 25;
eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_NO_NETWORK}) {
	plan tests => $tests;
} elsif (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} else {
	plan skip_all => 'No network. Unset RDFQUERY_NO_NETWORK to run these tests.';
	return;
}

use RDF::Query;


{
	print "# join using default graph (local rdf) and remote SERVICE (kasei.us), joining on bnode\n";
	my $file	= URI::file->new_abs( 'data/bnode-person.rdf' );
	my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		SELECT DISTINCT ?name ?nick
		FROM <$file>
		WHERE {
			?p a foaf:Person ; foaf:name ?name .
			SERVICE <http://kasei.us/sparql> {
				?p foaf:nick ?nick
			}
		}
END
	my $stream	= $query->execute();
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $d = $stream->next) {
		isa_ok( $d->{nick}, 'RDF::Query::Node::Literal' );
		like( $d->{name}->literal_value, qr/^(Adam Pisoni|Gregory Todd Williams)$/, 'got name from local file (joined on a bnode)' );
		like( $d->{nick}->literal_value, qr/^(wonko)$/, 'got nick from SERVICE (joined on a bnode)' );
		$count++;
	}
	is( $count, 1, 'expected result count' );
}

{
	my $file	= URI::file->new_abs( 'data/bnode-person.rdf' );
	
	my $bf		= Bloom::Filter->new( capacity => 2, error_rate => $RDF::Query::Algebra::Service::BLOOM_FILTER_ERROR_RATE );
	### This filter contains greg and adam, identified by a primaryTopic page and an email sha1sum, respectively:
	$bf->add('!<http://xmlns.com/foaf/0.1/mbox_sha1sum>"26fb6400147dcccfda59717ff861db9cb97ac5ec"');
	$bf->add('^<http://xmlns.com/foaf/0.1/primaryTopic><http://kasei.us/>');
	my $filter	= $bf->freeze;
	$filter		=~ s/\n/\\n/g;
	
	my $sparql	= <<"END";
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		PREFIX k: <http://kasei.us/code/rdf-query/functions/>
		SELECT DISTINCT *
		FROM <$file>
		WHERE {
			?p a foaf:Person ; foaf:name ?name .
			FILTER k:bloom( ?p, "${filter}" ) .
		}
END
	{
		print "# bgp using default graph (local rdf) with k:bloom FILTER produces bnode identity hints in XML results\n";
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparqlp' );
		my $stream	= $query->execute();
		my $xml		= $stream->as_xml;
		like( $xml, qr#<extrakey id="[^"]+">!&lt;http://xmlns.com/foaf/0.1/mbox_sha1sum>&quot;26fb6400147dcccfda59717ff861db9cb97ac5ec&quot;</extrakey>#sm, 'xml serialization has good looking bnode map' );
	}
	{
		print "# bgp using default graph (local rdf) with k:bloom FILTER\n";
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparqlp' );
		my $stream	= $query->execute();
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		
		my $count	= 0;
		while (my $d = $stream->next) {
			isa_ok( $d->{name}, 'RDF::Query::Node::Literal' );
			like( $d->{name}->literal_value, qr/^(Adam Pisoni|Gregory Todd Williams)$/, 'expected name passed from person passing through bloom filter' );
			$count++;
		}
		is( $count, 2, 'expected result count' );
	}
}

{
	print "# join using default graph (remote rdf) and remote SERVICE (kasei.us), joining on IRI\n";
	my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT *
		FROM <http://kasei.us/about/foaf.xrdf>
		WHERE {
			{
				?p a foaf:Person .
				FILTER( ISIRI(?p) )
			}
			SERVICE <http://kasei.us/sparql> {
				?p foaf:name ?name
			}
		}
END
	my $stream	= $query->execute();
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	my $d	= $stream->next;
	isa_ok( $d, 'HASH' );
	isa_ok( $d->{p}, 'RDF::Trine::Node::Resource' );
	is( $d->{p}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'expected person uri' );
	isa_ok( $d->{name}, 'RDF::Trine::Node::Literal' );
	is( $d->{name}->literal_value, 'Gregory Todd Williams', 'expected person name' );
}

{
	print "# join using default graph (remote rdf) and remote SERVICE (dbpedia), joining on IRI\n";
	my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		SELECT DISTINCT *
		FROM <http://dbpedia.org/resource/Vancouver_Island>
		WHERE {
			{
				?thing rdfs:label ?label .
				FILTER( LANGMATCHES( LANG(?label), "en" ) )
			}
			SERVICE <http://dbpedia.org/sparql> {
				?thing a <http://dbpedia.org/class/yago/Island109316454>
				FILTER( REGEX( STR(?thing), "http://dbpedia.org/resource/V" ) ) .
			}
		}
END
	my $stream	= $query->execute();
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	my $d	= $stream->next;
	isa_ok( $d, 'HASH' );
	isa_ok( $d->{label}, 'RDF::Trine::Node::Literal' );
	is( $d->{label}->literal_value, 'Vancouver Island', 'expected (island) name' );
	is( $d->{label}->literal_value_language, 'en', 'expected (island) name language' );
	isa_ok( $d->{thing}, 'RDF::Trine::Node::Resource' );
	is( $d->{thing}->uri_value, 'http://dbpedia.org/resource/Vancouver_Island', 'expected (island) uri' );
}
