use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok( 'RDF::Trine::Node::Literal::XML' );
use_ok( 'XML::LibXML' );


throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>bar', 'tlh');
} 'RDF::Trine::Error', 'throws on invalid xml without optional datatype';


lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>', 'tlh');
} 'lives on valid empty-element xml without optional datatype';


{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root><bar>baz</bar><foo>dahut</foo></root>');
  my $nodes = $doc->findnodes('/root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<bar xml:lang="tlh">baz</bar><foo xml:lang="tlh">dahut</foo>', 'nodelist expected literal value with lang set' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root><bar xml:lang="en">baz</bar><foo>dahut</foo></root>');
  my $nodes = $doc->findnodes('/root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<bar xml:lang="tlh">baz</bar><foo xml:lang="tlh">dahut</foo>', 'nodelist expected literal value with lang overridden' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}


{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root><bar xml:lang="en">baz</bar><foo>dahut</foo></root>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<root xml:lang="tlh"><bar xml:lang="en">baz</bar><foo>dahut</foo></root>', 'Document expected literal value with lang on root' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::Document' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_balanced_chunk( '<root><bar xml:lang="en">baz</bar><foo>dahut</foo></root>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<root xml:lang="tlh"><bar xml:lang="en">baz</bar><foo>dahut</foo></root>', 'Documentfragment expected literal value with lang on root' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::DocumentFragment' );
}


{
  my $l	= RDF::Trine::Node::Literal::XML->new( '<foo>bar</foo>', 'tlh');
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<foo xml:lang="tlh">bar</foo>', 'expected literal value with lang set' );
  is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::DocumentFragment' );
}

{ 
  my $node = XML::LibXML::Element->new( 'foo' );
  $node->appendTextNode('dahut');
  my $l	= RDF::Trine::Node::Literal::XML->new( $node, 'tlh');
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<foo xml:lang="tlh">dahut</foo>', 'expected literal value with lang set' );
  is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::Element' );
}



{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<ex:root xmlns:ex="http://example.org/ns"><ex:bar xml:lang="en">baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>');
  my $nodes = $doc->findnodes('/ex:root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<ex:bar xmlns:ex="http://example.org/ns" xml:lang="tlh">baz</ex:bar><ex:foo xmlns:ex="http://example.org/ns" xml:lang="tlh">dahut</ex:foo>', 'nodelist expected literal value with lang overridden and namespaces' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}


{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<ex:root xmlns:ex="http://example.org/ns"><ex:bar xml:lang="en">baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<ex:root xmlns:ex="http://example.org/ns" xml:lang="tlh"><ex:bar xml:lang="en">baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>', 'Document expected literal value with lang on root and namespaces' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::Document' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_balanced_chunk( '<ex:root xmlns:ex="http://example.org/ns"><ex:bar xml:lang="en">baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc, 'tlh' );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<ex:root xmlns:ex="http://example.org/ns" xml:lang="tlh"><ex:bar xml:lang="en">baz</ex:bar><ex:foo>dahut</ex:foo></ex:root>', 'Documentfragment expected literal value with lang on root and namespaces' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::DocumentFragment' );
}



done_testing;
