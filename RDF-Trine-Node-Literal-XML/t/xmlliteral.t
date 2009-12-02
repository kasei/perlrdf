use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok( 'RDF::Trine::Node::Literal::XML' );
use_ok( 'XML::LibXML' );

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>bar');
} 'RDF::Trine::Error', 'throws on invalid xml without optional arguments';

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>bar', 'tlh');
} 'RDF::Trine::Error', 'throws on invalid xml without optional datatype';


throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';



lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid empty-element xml';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>' );
} 'lives on valid empty-element xml without optional arguments';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>', 'tlh');
} 'lives on valid empty-element xml without optional datatype';


lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on element xml with content at the end';


lives_ok {
	my $l	= RDF::Trine::Node::Literal::XML->new( 'baz<bar>baz</bar><foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid two-element with content xml';

{
	my $l	= RDF::Trine::Node::Literal::XML->new( 'foo', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	isa_ok( $l, 'RDF::Trine::Node::Literal' );
	is( $l->literal_value, 'foo', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}

{
	my $l	= RDF::Trine::Node::Literal::XML->new( '<foo>bar</foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<foo>bar</foo>', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}

{
	my $l	= RDF::Trine::Node::Literal::XML->new( '<foo/>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<foo/>bar', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
	my $el	= $l->xml_element;
	isa_ok( $el, 'XML::LibXML::DocumentFragment' );
}


{
	my $el	= XML::LibXML::Element->new( 'a' );
	my $l	= RDF::Trine::Node::Literal::XML->new( $el );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<a/>', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}

{
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root><bar>baz</bar><foo>dahut</foo></root>');
  my $nodes = $doc->findnodes('/root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes );
  isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
  is( $l->literal_value, '<bar>baz</bar><foo>dahut</foo>', 'nodelist expected literal value' );
  my $el = $l->xml_element;
  isa_ok( $el, 'XML::LibXML::NodeList' );
}


throws_ok {
	my $text = XML::LibXML::Text->new('text');
	my $l	= RDF::Trine::Node::Literal::XML->new( $text );
} 'RDF::Trine::Error', 'throws on text node';

lives_ok { 
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<bar>baz</bar>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc );
} 'lives on document node';


lives_ok { 
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_balanced_chunk( '<bar>baz</bar>');
  my $l	= RDF::Trine::Node::Literal::XML->new( $doc );
} 'lives on documentfragment node';


lives_ok { 
  my $node = XML::LibXML::CDATASection->new( '<cdata>' );
  my $l	= RDF::Trine::Node::Literal::XML->new( $node );
} 'lives on cdatasection';


lives_ok { 
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_string( '<root><bar>baz</bar><foo>dahut</foo></root>');
  my $nodes = $doc->findnodes('/root/*');
  my $l	= RDF::Trine::Node::Literal::XML->new( $nodes );
} 'lives on nodelist';

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


done_testing;
