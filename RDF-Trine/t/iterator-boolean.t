#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 8;
use Test::Exception;
use Test::JSON;

use Data::Dumper;
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Boolean;
use RDF::Trine::Statement;

{
	my $stream	= RDF::Trine::Iterator::Boolean->new([1]);
	isa_ok( $stream, 'RDF::Trine::Iterator::Boolean' );
	ok( $stream->is_boolean, 'is_boolean' );
	ok( $stream->get_boolean, 'boolean value' );
}

{
	my $stream	= RDF::Trine::Iterator::Boolean->new([0]);
	isa_ok( $stream, 'RDF::Trine::Iterator::Boolean' );
	ok( $stream->is_boolean, 'is_boolean' );
	ok( not($stream->get_boolean), 'boolean value' );
}

{
	my $stream	= RDF::Trine::Iterator::Boolean->new( [1] );
	my $xml		= $stream->as_xml;
	like( $xml, qr#<boolean>true</boolean>#sm, 'boolean iterator as_xml' );
}

{
	my $stream	= RDF::Trine::Iterator::Boolean->new( [0] );
	my $json	= $stream->as_json;
	is_json( $json, '{"boolean":false,"head":{"vars":[]}}', 'boolean iterator as_json' );
}

