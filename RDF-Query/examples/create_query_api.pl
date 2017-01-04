#!/usr/bin/env perl
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

# add a LIMIT clause
my $limit	= RDF::Query::Algebra::Limit->new( $filter, 5 );

# and a PROJECT to get the variable list
my $proj	= RDF::Query::Algebra::Project->new( $limit, [map {RDF::Query::Node::Variable->new($_) } qw(a b)] );

# you still need to add the method (SELECT) yourself. at some point, the code
# from RDF::Query::describe, RDF::Query::construct and RDF::Query::ask will be
# moved into ::Algebra subclasses, and then we won't need to do this manually.
# until then, just tag on 'SELECT ' onto the front of the query string.
print 'SELECT ' . $proj->as_sparql;

# should print:
# SELECT * WHERE {
# 	?a <http://example.org/a> "a" .
# 	?a <http://example.org/b> ?b .
# 	FILTER (?b < 3) .
# }
# LIMIT 5
