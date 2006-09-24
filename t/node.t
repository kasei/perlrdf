#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use_ok( 'RDF::Base::Node' );
use_ok( 'RDF::Base::Node::Literal' );
use_ok( 'RDF::Base::Node::Resource' );
use_ok( 'RDF::Base::Node::Variable' );
use_ok( 'RDF::Base::Node::Blank' );

{
	my $subj		= RDF::Base::Node::Resource->new( uri => "foo:bar" );
	isa_ok( $subj, 'RDF::Base::Node::Resource' );
	
	my $pred		= RDF::Base::Node::Resource->new( uri => URI->new("http://xmlns.com/foaf/0.1/name") );
	isa_ok( $pred, 'RDF::Base::Node::Resource' );
	
	my $obj			= RDF::Base::Node::Literal->new( value => "greg" );
	isa_ok( $obj, 'RDF::Base::Node::Literal' );
	
	my $time		= time();
	my $blank		= RDF::Base::Node::Blank->new( name => $time );
	is( $blank->blank_identifier, $time, 'blank_identifier' );
	
	my $blank2		= RDF::Base::Node::Blank->new();
	my $blank3		= RDF::Base::Node::Blank->new();
	isa_ok( $blank, 'RDF::Base::Node::Blank' );
	isa_ok( $blank2, 'RDF::Base::Node::Blank' );
	isa_ok( $blank3, 'RDF::Base::Node::Blank' );
	
	dies_ok {
		my $literal	= RDF::Base::Node::Literal->new( value => 'foo', language => 'en', datatype => "http://www.w3.org/2001/XMLSchema#string" );
	} 'literal constructor throws on language-datatype';
	
	ok( $subj->equal( $subj ), 'resource-resource equality' );
	ok( not($subj->equal( $pred )), 'resource-resource equality' );
	ok( not($pred->equal( $obj )), 'resource-literal equality' );
	ok( $blank->equal( RDF::Base::Node::Blank->new( name => $time ) ), 'blank equality' );
	ok( not($blank2->equal( $blank3 )), 'blank equality' );
	ok( not($blank2->equal( $obj )), 'blank equality' );
	
	is( $subj->uri_value, 'foo:bar', 'resource-uri accessor' );
	is( $pred->uri_value, 'http://xmlns.com/foaf/0.1/name', 'resource-uri accessor' );
	is( $obj->value, 'greg', 'literal-value accessor' );
	ok( not($obj->has_language), 'literal-has_language accessor' );
	ok( not($obj->has_datatype), 'literal-has_datatype accessor' );
	is( $blank->name, $time, 'blank-name accessor' );
	like( $blank2->name, qr/^r\d+r\d+$/, 'blank-name accessor' );
}

{
	my $p		= RDF::Base::Node::Variable->new( name => "person" );
	my $n		= RDF::Base::Node::Variable->new( name => "name" );
	
	ok( $p->is_node, 'is_node' );
	ok( not($p->is_resource), 'is_resource' );
	ok( not($p->is_literal), 'is_literal' );
	ok( not($p->is_blank), 'is_blank' );
	ok( $p->is_variable, 'is_variable' );
	ok( not($p->equal( $n )), 'variable equality' );
	ok( not($p->equal( 0 )), 'variable equality' );
	is( $p->as_string, '?person', 'variable as_string' );
}

{
	my $name	= RDF::Base::Node::Literal->new( value => "greg" );
	my $name_en	= RDF::Base::Node::Literal->new( value => "greg", language => 'en' );
	my $name_us	= RDF::Base::Node::Literal->new( value => "greg", language => 'en-us' );
	my $name_dt	= RDF::Base::Node::Literal->new( value => "greg", datatype => 'http://example.com/name' );
	my $nick	= RDF::Base::Node::Literal->new( value => "kasei" );
	my $nick_en	= RDF::Base::Node::Literal->new( value => "kasei", language => 'en' );
	my $nick_us	= RDF::Base::Node::Literal->new( value => "kasei", language => 'en-us' );
	my $nick_dt	= RDF::Base::Node::Literal->new( value => "kasei", datatype => 'http://example.com/name' );
	my $quote	= RDF::Base::Node::Literal->new( value => "D'oh" );
	
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
	
	like( $name->as_string, qr#(['"])greg\1#, 'literal as_string' );
	like( $name_en->as_string, qr#(['"])greg\1[@]en#, 'literal@lang as_string' );
	like( $name_dt->as_string, qr#(['"])greg\1\^\^<http://example.com/name>#, 'literal^^<dt> as_string' );
	is( $quote->as_string, q("D'oh"), 'literal as_string' );
}

{
	my $uri		= RDF::Base::Node::Resource->new( uri => "urn:foo" );
	ok( $uri->is_node, 'is_node' );
	ok( $uri->is_resource, 'is_resource' );
	ok( not($uri->is_literal), 'is_literal' );
	ok( not($uri->is_blank), 'is_blank' );
	ok( not($uri->is_variable), 'is_variable' );
	my $node	= RDF::Base::Node->parse('[urn:foo]');
	
	ok( $uri->equal( $node ), 'parse uri' );
	ok( not($uri->equal( 0 )), 'uri equality' );
	
	is( $uri->as_string, '[urn:foo]', 'resource as_string' );
}

{
	my $blank	= RDF::Base::Node::Blank->new( name => "quux" );
	ok( $blank->is_node, 'is_node' );
	ok( not($blank->is_resource), 'is_resource' );
	ok( not($blank->is_literal), 'is_literal' );
	ok( $blank->is_blank, 'is_blank' );
	ok( not($blank->is_variable), 'is_variable' );
	my $node	= RDF::Base::Node->parse('(quux)');
	
	ok( $blank->equal( $node ), 'parse blank' );
	ok( not($blank->equal( 0 )), 'blank equality' );
	
	is( $blank->as_string, '(quux)', 'blank as_string' );
}

{
	{
		my $literal	= RDF::Base::Node::Literal->new( value => "blee" );
		ok( $literal->is_node, 'is_node' );
		ok( not($literal->is_resource), 'is_resource' );
		ok( $literal->is_literal, 'is_literal' );
		ok( not($literal->is_blank), 'is_blank' );
		ok( not($literal->is_variable), 'is_variable' );
		my $node	= RDF::Base::Node->parse(q("blee"));
		ok( $literal->equal( $node ), q(parse "-literal) );
	}
	
	{
		my $literal	= RDF::Base::Node::Literal->new( value => "blee" );
		my $node	= RDF::Base::Node->parse(q('blee'));
		ok( $literal->equal( $node ), q(parse '-literal) );
	}
	
	{
		my $literal	= RDF::Base::Node::Literal->new( value => "blee", language => 'en-us' );
		my $node	= RDF::Base::Node->parse(q("blee"@en-us));
		ok( $literal->equal( $node ), q(parse lang-literal) );
	}

	{
		my $literal	= RDF::Base::Node::Literal->new( value => "123", datatype => 'http://www.w3.org/2001/XMLSchema#integer' );
		my $node	= RDF::Base::Node->parse(q("123"^^<http://www.w3.org/2001/XMLSchema#integer>));
		ok( $literal->equal( $node ), q(parse dt-literal) );
	}
}

{
	is( RDF::Base::Node->parse(q("foo"@)), undef, 'bad literal language' );
	is( RDF::Base::Node->parse(q("foo"^^<>)), undef, 'bad literal datatype' );
	is( RDF::Base::Node->parse(q("foo"!)), undef, 'bad literal garbage' );
}
