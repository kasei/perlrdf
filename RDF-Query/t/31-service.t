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
	plan tests => 14;
} else {
	plan skip_all => 'No network. Unset RDFQUERY_NO_NETWORK to run these tests.';
	return;
}

my $loaded	= use_ok( 'RDF::Query' );
BAIL_OUT( 'RDF::Query not loaded' ) unless ($loaded);


{
	local($RDF::Query::Algebra::Service::debug)				= 1;
	local($RDF::Query::Functions::debug)					= 1;
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

exit;

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

if (1) {
	local($RDF::Query::Algebra::Service::debug)					= 1;
	unless ($ENV{RDFQUERY_DEV_TESTS}) {
		skip "developer network tests", 3;
	}
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
		use Data::Dumper;
		warn Dumper($d);
		isa_ok( $d->{nick}, 'RDF::Query::Node::Literal' );
		like( $d->{name}->literal_value, qr/^(Adam Pisoni|Gregory Todd Williams)$/ );
		like( $d->{nick}->literal_value, qr/^(wonko)$/ );
		$count++;
	}
	is( $count, 3 );
}

exit;
################################################################################

{
	my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT *
		FROM <http://kasei.us/about/foaf.xrdf>
		WHERE {
			?p a foaf:Person ; foaf:name ?name .
			FILTER <http://kasei.us/code/rdf-query/functions/bloom>( ?p, "BAcEMTIzNAQEBAgRDUJsb29tOjpGaWx0ZXIDCAAAAAoEAAAAAAgAAABibGFua3ZlYweamZmZmZmpPwoAAABlcnJvcl9yYXRlCggAAAFAAAgCAAYAAABmaWx0ZXIIhA4AAABudW1faGFzaF9mdW5jcwiBCQAAAGtleV9jb3VudAi/DQAAAGZpbHRlcl9sZW5ndGgIiggAAABjYXBhY2l0eQQCBAAAAAoRMC4zNzkxOTU0NDEyOTczOTQKETAuMjQ0MjQ5NjM2ODQ2NjkzChEwLjg1MTQ5ODA5NTE3NjMxMQoSMC4wNzgyMTI0NDE5NjY1MjA5BQAAAHNhbHRz" ) .
		}
END
	my $stream	= $query->execute();
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	my $d	= $stream->next;
	isa_ok( $d, 'HASH' );
	isa_ok( $d->{ name }, 'RDF::Trine::Node::Literal' );
	is( $d->{name}->literal_value, 'Gregory Todd Williams', 'expected value passed through bloom filter' );
}


SKIP: {
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

SKIP: {
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


SKIP: {
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

