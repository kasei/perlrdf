use Test::More tests => 9;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Node;
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

{
	local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 0;
	my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	is( ref($l), 'RDF::Trine::Node::Literal', 'object is a RDF::Trine::Node::Literal' );
}

SKIP: {
	if (RDF::Trine::Node::Literal::XML->can('new')) {
		lives_ok {
			local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 0;
			my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
		} 'lives on bad xml when ::Node::Literal::XML use is forced off';
		
		throws_ok {
			local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 1;
			my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
		} 'RDF::Trine::Error', 'throws on bad xml when ::Node::Literal::XML is available';
	} else {
		skip "RDF::Trine::Node::Literal::XML isn't available", 2;
	}
}

{
	my $l		= RDF::Trine::Node::Literal->new( '<foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	if (RDF::Trine::Node::Literal::XML->can('new')) {
		isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	} else {
		isa_ok( $l, 'RDF::Trine::Node::Literal' );
	}
}
