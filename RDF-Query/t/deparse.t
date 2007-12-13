#!/usr/bin/perl
use strict;
use warnings;
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);

use Test::More;
plan tests => 5;

use_ok( 'RDF::Query' );

{
	my $rdql	= qq{SELECT ?person WHERE (?person foaf:name "Gregory Todd Williams") USING foaf FOR <http://xmlns.com/foaf/0.1/>};
	my $query	= new RDF::Query ( $rdql, undef, undef, 'rdql' );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> SELECT * WHERE { ?person foaf:name "Gregory Todd Williams" }', 'rdql to sparql' );
}

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name } ORDER BY ?name";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name } ORDER BY ?name", 'sparql to sparql' );
}

{
	my $sparql	= 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person; foaf:homepage ?homepage . FILTER( REGEX( STR(?homepage), "^http://www.rpi.edu/.+") ) } ORDER BY ?p';
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person . ?p foaf:homepage ?homepage FILTER REGEX(STR( ?homepage ), "^http://www.rpi.edu/.+") } ORDER BY ?p', 'sparql to sparql with filter' );
}

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name } ORDER BY ?name LIMIT 5 OFFSET 5";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name } ORDER BY ?name LIMIT 5 OFFSET 5", 'sparql to sparql with slice' );
}
