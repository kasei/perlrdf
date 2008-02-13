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
	plan tests => 7;
} else {
	plan skip_all => 'No network. Unset RDFQUERY_NO_NETWORK to run these tests.';
	return;
}

my $loaded	= use_ok( 'RDF::Query' );
BAIL_OUT( "RDF::Query not loaded" ) unless ($loaded);



{
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

