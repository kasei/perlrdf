#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 17;

use RDF::Trine;
use RDF::Trine::Node;

{
	my $literal	= RDF::Trine::Node::Literal->new('foo');
	is( $literal->sse, '"foo"', 'plain literal sse' );
	is( $literal->as_string, '"foo"', 'plain literal as_string' );
}

{
	my $literal	= RDF::Trine::Node::Literal->new('foo', 'en');
	is( $literal->sse, '"foo"@en', 'language literal sse' );
	is( $literal->as_string, '"foo"@en', 'language literal as_string' );
}

{
	my $literal	= RDF::Trine::Node::Literal->new('1', undef, 'http://www.w3.org/2001/XMLSchema#integer');
	is( $literal->sse, '"1"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal sse' );
	is( $literal->as_string, '"1"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal as_string' );
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://example.org/');
	is( $uri->sse, '<http://example.org/>', 'uri sse' );
	is( $uri->as_string, '<http://example.org/>', 'uri as_string' );
}

{
	my $blank	= RDF::Trine::Node::Blank->new('b1');
	is( $blank->sse, '_:b1', 'blank sse' );
	is( $blank->as_string, '(b1)', 'blank as_string' );
}

{
	my $blank	= RDF::Trine::Node::Variable->new('person');
	is( $blank->sse, '?person', 'variable sse' );
	is( $blank->as_string, '?person', 'blank as_string' );
}

{
	my $string	= "\x04\x{10001}";
	my $literal	= RDF::Trine::Node::Literal->new($string);
	is( $literal->as_ntriples, '"\u0004\U00010001"', 'unicode escaping of x04x10001' );
}

{
	my $literal	= RDF::Trine::Node::Literal->new("\x7f");
	is( $literal->as_ntriples, '"\u007F"', 'unicode escaping of x7f' );
}

{
	my $literal	= RDF::Trine::Node::Literal->new(qq[a\r\t"\x80\x{10f000}b\x0b]);
	my $expect	= q["a\r\t\"\u0080\U0010F000b\u000B"];
	is( $literal->as_ntriples, $expect, 'unicode escaping of a\\r\\t"x{80}x{10f000}bx{0b}' );
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://example.org/bar');
	is( $uri->sse({ namespaces => { foo => 'http://example.org/' } }), 'foo:bar', 'uri sse with valid namespace' );
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://example.org/bar');
	is( $uri->sse({ namespaces => { foo => 'http://example.com/' } }), '<http://example.org/bar>', 'uri sse with invalid namespace' );
}


__END__
