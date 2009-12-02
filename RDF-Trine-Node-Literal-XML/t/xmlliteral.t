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
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';



lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid empty-element xml';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>' );
} 'lives on valid empty-element xml without optional arguments';



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


done_testing;
