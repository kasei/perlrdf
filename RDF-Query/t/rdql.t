#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use Test::More tests => 2;
use RDF::Query;

my $got = RDF::Query->new(<<'GO', { lang => 'rdql' }) or diag(RDF::Query->error);
SELECT ?s
WHERE ( ?s ?p ?o )
GO

my $expected = RDF::Query->new(<<'GO') or diag(RDF::Query->error);
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT ?s
WHERE { ?s ?p ?o }
GO

isa_ok($got => 'RDF::Query') or BAIL_OUT;
is($got->as_sparql, $expected->as_sparql);
