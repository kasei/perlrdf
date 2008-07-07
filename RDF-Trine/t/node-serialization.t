#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 12;

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

__END__
