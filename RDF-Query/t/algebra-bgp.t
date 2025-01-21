#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 7;
use Test::Exception;
use Scalar::Util qw(reftype blessed);

use RDF::Query;
use RDF::Query::Node;
use RDF::Query::Algebra;
use RDF::Query::Parser::SPARQL;

my $parser	= RDF::Query::Parser::SPARQL->new();

my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };

{
	my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person }', undef, $ns)->patterns;
	ok( $bgp->connected, 'single-connected BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
	ok( $bgp->connected, 'connected BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?a ?b ?c . ?c ?d ?e . ?e ?f ?g . ?g ?h ?i }', undef, $ns)->patterns;
	ok( $bgp->connected, 'connected chain BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?a ?b ?c . ?e ?f ?g . ?c ?d ?e . ?g ?h ?a }', undef, $ns)->patterns;
	ok( $bgp->connected, 'connected loop BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name ; foaf:knows ?q . ?q a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
	ok( $bgp->connected, '(multi-)connected BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person . ?q a foaf:Person }', undef, $ns)->patterns;
	ok( not($bgp->connected), 'non-connected two-triples BGP' );
}

{
	my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name . ?q a foaf:Person ; foaf:homepage ?h . ?h foaf:isPrimaryTopicOf ?t }', undef, $ns)->patterns;
	ok( not($bgp->connected), 'non-connected two-clusteres BGP' );
}

