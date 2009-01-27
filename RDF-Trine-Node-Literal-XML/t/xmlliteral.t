use Test::More qw(no_plan); #tests => 5;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok( 'RDF::Trine::Node::Literal::XML' );


throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';

throws_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'RDF::Trine::Error', 'throws on invalid xml';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid empty-element xml';

lives_ok {
	my $l		= RDF::Trine::Node::Literal::XML->new( '<foo/>bar', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
} 'lives on valid element xml';

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
	isa_ok( $el, 'XML::LibXML::Element' );
}

{
	my $el	= XML::LibXML::Element->new( 'a' );
	my $l	= RDF::Trine::Node::Literal::XML->new_from_element( $el );
	isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	is( $l->literal_value, '<a/>', 'expected literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral', 'expected literal datatype' );
}

