#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files;
my @models	= test_models( @files );

eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_NO_NETWORK}) {
	plan tests => 23;
} else {
	plan skip_all => 'No network. Unset RDFQUERY_NO_NETWORK to run these tests.';
	return;
}

use RDF::Query;

SKIP: {
#	local($RDF::Query::Algebra::Service::debug)					= 1;
	unless ($ENV{RDFQUERY_DEV_TESTS}) {
		skip "developer network tests", 3;
	}
	
	{
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
	# 	local($RDF::Query::Algebra::Service::debug)				= 1;
	# 	local($RDF::Query::Functions::debug)					= 1;
		unless ($ENV{RDFQUERY_DEV_TESTS}) {
			skip "developer network tests", 8;
		}
		my $file1	= URI::file->new_abs( '/Users/samofool/Sites/kasei.us/e/people/index.rdf' );
		my $file2	= URI::file->new_abs( 'data/bnode-person.rdf' );
		
		### This filter contains greg and adam, identified by a primaryTopic page and an email sha1sum, respectively:
		### !<http://xmlns.com/foaf/0.1/mbox_sha1sum>"26fb6400147dcccfda59717ff861db9cb97ac5ec"
		### ^<http://xmlns.com/foaf/0.1/primaryTopic><http://kasei.us/>
		my $sparql	= <<"END";
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX k: <http://kasei.us/code/rdf-query/functions/>
			SELECT DISTINCT *
			FROM <$file1>
			FROM <$file2>
			WHERE {
				?p a foaf:Person ; foaf:name ?name .
				FILTER k:bloom( ?p, "AAAAAgAAAB0AAAACAAAACgAAAAQAAAAFZJREZxMt9AekxG8jP9HulJISKVbFzR2rP9boeVledzCy\\nIqE/jWf8NvjRYRUwLjAwMQ==\\n" ) .
			}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparqlp' );
		my $stream	= $query->execute();
		my $xml		= $stream->as_xml;
		like( $xml, qr#<extrakey id="[^"]+">!&lt;http://xmlns.com/foaf/0.1/mbox_sha1sum>&quot;26fb6400147dcccfda59717ff861db9cb97ac5ec&quot;</extrakey>#sm, 'xml serialization has good looking bnode map' );
	}
	
	{
	# 	local($RDF::Query::Algebra::Service::debug)				= 1;
	# 	local($RDF::Query::Functions::debug)					= 1;
		unless ($ENV{RDFQUERY_DEV_TESTS}) {
			skip "developer network tests", 8;
		}
		my $file1	= URI::file->new_abs( '/Users/samofool/Sites/kasei.us/e/people/index.rdf' );
		my $file2	= URI::file->new_abs( 'data/bnode-person.rdf' );
		
		### This filter contains greg and adam, identified by a primaryTopic page and an email sha1sum, respectively:
		### !<http://xmlns.com/foaf/0.1/mbox_sha1sum>"26fb6400147dcccfda59717ff861db9cb97ac5ec"
		### ^<http://xmlns.com/foaf/0.1/primaryTopic><http://kasei.us/>
		my $sparql	= <<"END";
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX k: <http://kasei.us/code/rdf-query/functions/>
			SELECT DISTINCT *
			FROM <$file1>
			FROM <$file2>
			WHERE {
				?p a foaf:Person ; foaf:name ?name .
				FILTER k:bloom( ?p, "AAAAAgAAAB0AAAACAAAACgAAAAQAAAAFZJREZxMt9AekxG8jP9HulJISKVbFzR2rP9boeVledzCy\\nIqE/jWf8NvjRYRUwLjAwMQ==\\n" ) .
			}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparqlp' );
		my $stream	= $query->execute();
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		
		my $count	= 0;
		while (my $d = $stream->next) {
			isa_ok( $d->{name}, 'RDF::Query::Node::Literal' );
			like( $d->{name}->literal_value, qr/^(Adam Pisoni|Gregory Todd Williams)$/, 'expected name passed from person passing through bloom filter' );
			$count++;
		}
		is( $count, 3, 'expected result count' );
	}
	
	{
		unless ($ENV{RDFQUERY_DEV_TESTS}) {
			skip "developer network tests", 3;
		}
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
		is_deeply( $d, {
			'p' => bless( [
				'URI',
				'http://kasei.us/about/foaf.xrdf#greg',
			], 'RDF::Trine::Node::Resource' ),
			'name' => bless( [
				'LITERAL',
				'Gregory Todd Williams'
			], 'RDF::Trine::Node::Literal' )
		} );
	}
	
	{
		unless ($ENV{RDFQUERY_DEV_TESTS}) {
			skip "developer network tests", 3;
		}
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
				}
			}
END
		my $stream	= $query->execute();
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $d	= $stream->next;
		
		isa_ok( $d, 'HASH' );
		is_deeply( $d, {
			'label' => bless( [
				'LITERAL',
				'Vancouver Island',
				'en',
				undef
			], 'RDF::Trine::Node::Literal' ),
			'thing' => bless( [
				'URI',
				'http://dbpedia.org/resource/Vancouver_Island'
			], 'RDF::Trine::Node::Resource' )
		} );
	}
	
	
	{
		unless ($ENV{RDFQUERY_DEV_TESTS}) {
			skip "developer network tests", 3;
		}
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
	PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	SELECT *
	WHERE {
		SERVICE <http://dbpedia.org/sparql> {
			?thing a <http://dbpedia.org/class/yago/Island109316454>
		}
	}
END
		my $stream	= $query->execute();
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $d	= $stream->next;
		isa_ok( $d, 'HASH' );
		
		my @values	= values %$d;
		isa_ok( $values[0], 'RDF::Trine::Node' );
	}
}
