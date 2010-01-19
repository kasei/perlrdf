use Test::More tests => 14;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri blank literal variable);
use RDF::Trine::Namespace qw(xsd);

{
	my $r	= iri('http://kasei.us/');
	isa_ok( $r, 'RDF::Trine::Node::Resource' );
	is( $r->uri_value, 'http://kasei.us/', 'expected IRI value' );
}

{
	my $b	= blank('b1');
	isa_ok( $b, 'RDF::Trine::Node::Blank' );
	is( $b->blank_identifier, 'b1', 'expected blank node identifier' );
}

{
	my $l	= literal( 'text' );
	isa_ok( $l, 'RDF::Trine::Node::Literal' );
	is( $l->literal_value, 'text', 'expected literal value' );
}

{
	my $l	= literal( 'text', 'en' );
	isa_ok( $l, 'RDF::Trine::Node::Literal' );
	is( $l->literal_value, 'text', 'expected lang-literal value' );
	is( $l->literal_value_language, 'en', 'expected lang-literal language' );
}

{
	my $l	= literal( '123', undef, $xsd->integer );
	isa_ok( $l, 'RDF::Trine::Node::Literal' );
	is( $l->literal_value, '123', 'expected dt-literal value' );
	is( $l->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', 'expected dt-literal datatype' );
}

{
	my $v	= variable( 'x' );
	isa_ok( $v, 'RDF::Trine::Node::Variable' );
	is( $v->name, 'x', 'expected variable name' );
}


__END__
