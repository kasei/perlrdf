#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use RDF::Base::Node;
use RDF::Query::Node;
use RDF::Query::Node::Literal;
use RDF::Query::Node::Resource;
use RDF::Query::Node::Variable;
use RDF::Query::Node::Blank;

{
	my $subj		= RDF::Query::Node::Resource->new( "foo:bar" );
	isa_ok( $subj, 'RDF::Query::Node::Resource' );
	
	my $pred		= RDF::Query::Node::Resource->new( URI->new("http://xmlns.com/foaf/0.1/name") );
	isa_ok( $pred, 'RDF::Query::Node::Resource' );
	
	my $obj			= RDF::Query::Node::Literal->new( "greg" );
	isa_ok( $obj, 'RDF::Query::Node::Literal' );
	
	my $time		= time();
	my $blank		= RDF::Query::Node::Blank->new( $time );
	is( $blank->blank_identifier, $time, 'blank_identifier' );
	
	my $blank2		= RDF::Query::Node::Blank->new();
	my $blank3		= RDF::Query::Node::Blank->new();
	isa_ok( $blank, 'RDF::Query::Node::Blank' );
	isa_ok( $blank2, 'RDF::Query::Node::Blank' );
	isa_ok( $blank3, 'RDF::Query::Node::Blank' );
	
	dies_ok {
		my $literal	= RDF::Query::Node::Literal->new( 'foo', 'en', "http://www.w3.org/2001/XMLSchema#string" );
	} 'literal constructor throws on language-datatype';
	
	ok( $subj->equal( $subj ), 'resource-resource equality' );
	ok( not($subj->equal( $pred )), 'resource-resource equality' );
	ok( not($pred->equal( $obj )), 'resource-literal equality' );
	ok( $blank->equal( RDF::Query::Node::Blank->new( $time ) ), 'blank equality' );
	ok( not($blank2->equal( $blank3 )), 'blank equality' );
	ok( not($blank2->equal( $obj )), 'blank equality' );
	
	is( $subj->uri_value, 'foo:bar', 'resource-uri accessor' );
	is( $pred->uri_value, 'http://xmlns.com/foaf/0.1/name', 'resource-uri accessor' );
	is( $obj->literal_value, 'greg', 'literal-value accessor' );
	ok( not($obj->has_language), 'literal-has_language accessor' );
	ok( not($obj->has_datatype), 'literal-has_datatype accessor' );
	is( $blank->blank_identifier, $time, 'blank-name accessor' );
	like( $blank2->blank_identifier, qr/^r\d+r\d+$/, 'blank-name accessor' );
}

{
	my $p		= RDF::Query::Node::Variable->new( "person" );
	my $n		= RDF::Query::Node::Variable->new( "name" );
	
	ok( $p->is_node, 'is_node' );
	ok( not($p->is_resource), 'is_resource' );
	ok( not($p->is_literal), 'is_literal' );
	ok( not($p->is_blank), 'is_blank' );
	ok( $p->is_variable, 'is_variable' );
	ok( not($p->equal( $n )), 'variable equality' );
	ok( not($p->equal( 0 )), 'variable equality' );
	is( $p->name, 'person', 'variable as_string' );
}

{
	my $name	= RDF::Query::Node::Literal->new( "greg" );
	my $name_en	= RDF::Query::Node::Literal->new( "greg", 'en' );
	my $name_us	= RDF::Query::Node::Literal->new( "greg", 'en-us' );
	my $name_dt	= RDF::Query::Node::Literal->new( "greg", undef, 'http://example.com/name' );
	my $nick	= RDF::Query::Node::Literal->new( "kasei" );
	my $nick_en	= RDF::Query::Node::Literal->new( "kasei", 'en' );
	my $nick_us	= RDF::Query::Node::Literal->new( "kasei", 'en-us' );
	my $nick_dt	= RDF::Query::Node::Literal->new( "kasei", undef, 'http://example.com/name' );
	my $quote	= RDF::Query::Node::Literal->new( "D'oh" );
	
	ok( not($name_dt->equal( 0 )), 'literal equality [1]' );
	
	foreach my $test ($name_en, $name_us, $name_dt, $nick, $nick_en, $nick_us, $nick_dt) {
		ok( not($name->equal( $test )), 'literal equality [2]' );
	}

	foreach my $test ($name, $name_us, $name_dt, $nick, $nick_en, $nick_us, $nick_dt) {
		ok( not($name_en->equal( $test )), 'literal equality [3]' );
	}

	foreach my $test ($name, $nick_dt) {
		ok( not($name_dt->equal( $test )), 'literal equality [4]' );
	}
	
	like( $name->as_sparql, qr#(['"])greg\1#, 'literal as_string' );
	like( $name_en->as_sparql, qr#(['"])greg\1[@]en#, 'literal@lang as_string' );
	like( $name_dt->as_sparql, qr#(['"])greg\1\^\^<http://example.com/name>#, 'literal^^<dt> as_string' );
	is( $quote->as_sparql, q("D'oh"), 'literal as_string' );
}

{
	my $uri		= RDF::Query::Node::Resource->new( "urn:foo" );
	ok( $uri->is_node, 'is_node' );
	ok( $uri->is_resource, 'is_resource' );
	ok( not($uri->is_literal), 'is_literal' );
	ok( not($uri->is_blank), 'is_blank' );
	ok( not($uri->is_variable), 'is_variable' );
	my $node	= RDF::Base::Node->parse('[urn:foo]');
	
	ok( $uri->equal( $node ), 'parse uri' );
	ok( not($uri->equal( 0 )), 'uri equality' );
	
	is( $uri->as_sparql, '<urn:foo>', 'resource as_string' );
}

{
	my $blank	= RDF::Query::Node::Blank->new( "quux" );
	ok( $blank->is_node, 'is_node' );
	ok( not($blank->is_resource), 'is_resource' );
	ok( not($blank->is_literal), 'is_literal' );
	ok( $blank->is_blank, 'is_blank' );
	ok( not($blank->is_variable), 'is_variable' );
	my $node	= RDF::Base::Node->parse('(quux)');
	
	ok( $blank->equal( $node ), 'parse blank' );
	ok( not($blank->equal( 0 )), 'blank equality' );
	
	is( $blank->as_sparql, '_:quux', 'blank as_string' );
}

{
	{
		my $literal	= RDF::Query::Node::Literal->new( "blee" );
		ok( $literal->is_node, 'is_node' );
		ok( not($literal->is_resource), 'is_resource' );
		ok( $literal->is_literal, 'is_literal' );
		ok( not($literal->is_blank), 'is_blank' );
		ok( not($literal->is_variable), 'is_variable' );
		my $node	= RDF::Base::Node->parse(q("blee"));
		ok( $literal->equal( $node ), q(parse "-literal) );
	}
	
	{
		my $literal	= RDF::Query::Node::Literal->new( "blee" );
		my $node	= RDF::Base::Node->parse(q('blee'));
		ok( $literal->equal( $node ), q(parse '-literal) );
	}
	
	{
		my $literal	= RDF::Query::Node::Literal->new( "blee", 'en-us' );
		my $node	= RDF::Base::Node->parse(q("blee"@en-us));
		ok( $literal->equal( $node ), q(parse lang-literal) );
	}

	{
		my $literal	= RDF::Query::Node::Literal->new( "123", undef, 'http://www.w3.org/2001/XMLSchema#integer' );
		my $node	= RDF::Base::Node->parse(q("123"^^<http://www.w3.org/2001/XMLSchema#integer>));
		ok( $literal->equal( $node ), q(parse dt-literal) );
	}
}

{
	is( RDF::Base::Node->parse(q("foo"@)), undef, 'bad literal language' );
	is( RDF::Base::Node->parse(q("foo"^^<>)), undef, 'bad literal datatype' );
	is( RDF::Base::Node->parse(q("foo"!)), undef, 'bad literal garbage' );
}
