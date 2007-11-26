#!/usr/bin/perl
use strict;
use warnings;
use URI::file;
use Test::More tests => 38;

use Data::Dumper;
use RDF::SPARQLResults;

{
	my @data	= ([1],[2],[3]);
	my $stream	= RDF::SPARQLResults->new( \@data, 'bindings', [qw(value)] );
	isa_ok( $stream, 'RDF::SPARQLResults' );
	ok( $stream->is_bindings, 'is_bindings' );
	is( $stream->is_boolean, 0, 'is_boolean' );
	is( $stream->is_graph, 0, 'is_graph' );
	
	my @values	= $stream->get_all;
	is_deeply( \@values, [[1], [2], [3]], 'deep comparison' );
}

{
	my @data	= ([1],[2]);
	my @sources	= ([@data], sub { shift(@data) });
	foreach my $data (@sources) {
		my $stream	= RDF::SPARQLResults->new( $data, 'bindings', [qw(value)] );
		my $first	= $stream->next_result;
		isa_ok( $first, 'ARRAY' );
		is( $first->[0], 1 );
		
		my $second	= $stream->next;
		isa_ok( $second, 'ARRAY' );
		is( $second->[0], 2 );
		
		my @names	= $stream->binding_names;
		is_deeply( \@names, [qw(value)], 'binding_names' );
		
		is( $stream->binding_name( 0 ), 'value' );
		
		is( $stream->binding_value_by_name('value'), 2, 'binding_value_by_name' );
		is( $stream->binding_value(0), 2, 'binding_value' );
		my @values	= $stream->binding_values;
		is_deeply( \@values, [2], 'binding_values' );
		
		is( $stream->bindings_count, 1 );
		
		is( $stream->finished, 0, 'not finished' );
		is( $stream->open, 1, 'open' );
		my $row		= $stream->next;
		is( $row, undef );
		is( $stream->finished, 1, 'finished' );
		is( $stream->open, 1, 'not open' );
	}
}

{
	my $true	= RDF::SPARQLResults->new( [1], 'boolean' );
	isa_ok( $true, 'RDF::SPARQLResults' );
	is( $true->get_boolean, 1, 'get_boolean' );
	my $false	= RDF::SPARQLResults->new( [0], 'boolean' );
	is( $false->get_boolean, 0, 'get_boolean' );
}

