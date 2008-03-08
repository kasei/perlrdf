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


SKIP: {
	unless ($ENV{RDFQUERY_DEV_TESTS}) {
		skip "developer network tests", 4;
	}
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

