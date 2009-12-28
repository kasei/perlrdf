use Test::More tests => 37;
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
my $a		= RDF::Trine::Node::Blank->new('a');
my $b		= RDF::Trine::Node::Blank->new();
my $l		= RDF::Trine::Node::Literal->new( 'value' );
my $ll		= RDF::Trine::Node::Literal->new( 'value', 'en' );
my $dl		= RDF::Trine::Node::Literal->new( '123', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $p		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
my $name	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/name');

ok( $a->is_node, 'is_node' );
ok( not($a->is_resource), '!is_resource' );
ok( not($p->is_blank), '!is_blank' );
ok( not($p->is_variable), '!is_variable' );

ok( $a->equal( $a ), 'blank equal' );
ok( not($a->equal( $b )), 'blank not-equal' );
ok( $name->equal( $foaf->name ), 'resource equal' );
ok( not($name->equal( $p )), 'resource not-equal' );
ok( not($a->equal( $name )), 'blank-resource not-equal' );

# as_string
is( $a->as_string, '(a)', 'blank as_string' );
is( $l->as_string, '"value"', 'plain literal as_string' );
is( $ll->as_string, '"value"@en', 'language literal as_string' );
is( $dl->as_string, '"123"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal as_string' );
is( $p->as_string, '<http://kasei.us/about/foaf.xrdf#greg>', 'resource as_string' );

# as_ntriples
is( $a->as_ntriples, '_:a', 'blank as_ntriples' );
is( $l->as_ntriples, '"value"', 'plain literal as_ntriples' );
is( $ll->as_ntriples, '"value"@en', 'language literal as_ntriples' );
is( $dl->as_ntriples, '"123"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal as_ntriples' );
is( $p->as_ntriples, '<http://kasei.us/about/foaf.xrdf#greg>', 'resource as_ntriples' );

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

# from_sse
{
	my $n	= RDF::Trine::Node->from_sse( '(a)' );
	isa_ok( $n, 'RDF::Trine::Node::Blank', 'blank from_sse' );
	is( $n->blank_identifier, 'a', 'blank from_sse identifier' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '<iri>' );
	isa_ok( $n, 'RDF::Trine::Node::Resource', 'resource from_sse' );
	is( $n->uri_value, 'iri', 'resource from_sse identifier' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'literal from_sse' );
	is( $n->literal_value, 'value', 'literal from_sse value' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"@en' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'language literal from_sse' );
	is( $n->literal_value, 'value', 'language literal from_sse value' );
	is( $n->literal_value_language, 'en', 'language literal from_sse language' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"^^<dt>' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'datatype literal from_sse' );
	is( $n->literal_value, 'value', 'datatype literal from_sse value' );
	is( $n->literal_datatype, 'dt', 'datatype literal from_sse datatype' );
}

{
	my $ctx	= { namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' } };
	my $n	= RDF::Trine::Node->from_sse( 'foaf:name', $ctx );
	isa_ok( $n, 'RDF::Trine::Node::Resource', 'resource from_sse' );
	is( $n->uri_value, 'http://xmlns.com/foaf/0.1/name', 'qname from_sse identifier' );
}
