use Test::More tests => 6;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok 'RDF::Trine::Node';
use RDF::Trine::Namespace;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');
my $a		= RDF::Trine::Node::Blank->new();
my $b		= RDF::Trine::Node::Blank->new();
my $p		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
my $name	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/name');

ok( $a->equal( $a ), 'blank equal' );
ok( not($a->equal( $b )), 'blank not-equal' );

ok( $name->equal( $foaf->name ), 'resource equal' );
ok( not($name->equal( $p )), 'resource not-equal' );

ok( not($a->equal( $name )), 'blank-resource not-equal' );
