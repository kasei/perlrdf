#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Data::Dumper;
use Scalar::Util qw(reftype blessed);

use RDF::Query;

my $la		= RDF::Query::Node::Literal->new( 'a' );
my $l3		= RDF::Query::Node::Literal->new( '3', undef, 'http://www.w3.org/2001/XMLSchema#integer' );

my $ra		= RDF::Query::Node::Resource->new( 'http://example.org/a' );
my $rb		= RDF::Query::Node::Resource->new( 'http://example.org/b' );

my $va		= RDF::Query::Node::Variable->new( 'a' );
my $vb		= RDF::Query::Node::Variable->new( 'b' );

# construct a BGP with two triples { ?a :b "a" ; :b ?b }
my $triplea	= RDF::Query::Algebra::Triple->new( $va, $ra, $la );
my $tripleb	= RDF::Query::Algebra::Triple->new( $va, $rb, $vb );
my $bgp		= RDF::Query::Algebra::BasicGraphPattern->new( $triplea, $tripleb );

# now add a filter, and wrap it in a GGP { ?a :b "a" ; :b ?b . FILTER(?b < 3) }
my $expr	= RDF::Query::Expression::Binary->new( '<', $vb, $l3 );
my $filter	= RDF::Query::Algebra::Filter->new( $expr, $bgp );
my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( $filter );

# and add a LIMIT clause
my $limit	= RDF::Query::Algebra::Limit->new( $filter, 5 );

printf("SELECT * WHERE %s\n", $limit->as_sparql);

# should print:
# SELECT * WHERE {
# 	?a <http://example.org/a> "a" .
# 	?a <http://example.org/b> ?b .
# 	FILTER (?b < 3) .
# }
# LIMIT 5
