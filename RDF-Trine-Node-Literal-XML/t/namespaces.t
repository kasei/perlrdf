use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok( 'RDF::Trine::Node::Literal::XML' );
use_ok( 'XML::LibXML' );

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo>bar');
} 'RDF::Trine::Error', 'throws on invalid xml without optional arguments';


throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';



throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on valid empty-element xml with undeclared ns prefix';

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo/>' );
}  'RDF::Trine::Error', 'throws on valid empty-element xml without optional arguments with undeclared ns prefix';



throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo/>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on element xml with content at the end with undeclared ns prefix';


throws_ok {
	my $l	= RDF::Trine::Node::Literal::XML->new( 'baz<ex:bar>baz</ex:bar><ex:foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on valid two-element with content xml with undeclared ns prefix';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo xmlns:ex="http://example.org/ns"/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid empty-element xml';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo xmlns:ex="http://example.org/ns"/>' );
} 'lives on valid empty-element xml without optional arguments';



lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<ex:foo xmlns:ex="http://example.org/ns"/>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on element xml with content at the end';


lives_ok {
	my $l	= RDF::Trine::Node::Literal::XML->new( 'baz<ex:bar xmlns:ex="http://example.org/ns">baz</ex:bar><ex:foo xmlns:ex="http://example.org/ns"/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid two-element with content xml';



{
	my $l	= RDF::Trine::Node::Literal::XML->new( '<ex:foo xmlns:ex="http://example.org/ns">bar</ex:foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<ex:foo xmlns:ex="http://example.org/ns">bar</ex:foo>', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}



{
	my $el	= XML::LibXML::Element->new( 'a' );
	$el->setNamespace( 'http://example.org/ns' , 'ex');
	my $l	= RDF::Trine::Node::Literal::XML->new( $el );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<ex:a xmlns:ex="http://example.org/ns"/>', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<ex:root xmlns:ex="http://example.org/ns"><ex:bar>baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>');
  my $nodes = $doc->findnodes('/ex:root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<ex:bar xmlns:ex="http://example.org/ns">baz</ex:bar><ex:foo xmlns:ex="http://example.org/ns">dahut</ex:foo>', 'nodelist expected literal value' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<ex:root xmlns:ex="http://example.org/ns"><ex:bar>baz</ex:bar><foo>dahut</foo></ex:root>');
  my $nodes = $doc->findnodes('/ex:root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<ex:bar xmlns:ex="http://example.org/ns">baz</ex:bar><foo>dahut</foo>', 'nodelist expected literal value' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root xmlns="http://example.org/ns"><bar>baz</bar><foo>dahut</foo></root>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<root xmlns="http://example.org/ns"><bar>baz</bar><foo>dahut</foo></root>', 'document expected literal value, default namespace' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::Document' );
}




done_testing;
