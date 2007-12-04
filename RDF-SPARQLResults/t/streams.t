#!/usr/bin/perl
use strict;
use warnings;
use URI::file;
use Test::More tests => 45;

use Data::Dumper;
use RDF::SPARQLResults;

{
	my @data	= ({value=>1},{value=>2},{value=>3});
	my $stream	= RDF::SPARQLResults::Bindings->new( \@data, [qw(value)] );
	isa_ok( $stream, 'RDF::SPARQLResults' );
	ok( $stream->is_bindings, 'is_bindings' );
	is( $stream->is_boolean, 0, 'is_boolean' );
	is( $stream->is_graph, 0, 'is_graph' );
	
	my @values	= $stream->get_all;
	is_deeply( \@values, [{value=>1}, {value=>2}, {value=>3}], 'deep comparison' );
}

{
	my @data	= ({value=>1},{value=>2});
	my @sources	= ([@data], sub { shift(@data) });
	foreach my $data (@sources) {
		my $stream	= RDF::SPARQLResults::Bindings->new( $data, [qw(value)] );
		my $first	= $stream->next_result;
		isa_ok( $first, 'HASH' );
		is( $first->{value}, 1 );
		
		my $second	= $stream->next;
		isa_ok( $second, 'HASH' );
		is( $second->{value}, 2 );
		
		my @names	= $stream->binding_names;
		is_deeply( \@names, [qw(value)], 'binding_names' );
		is( $stream->binding_name( 0 ), 'value', 'binding_name' );
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
	my $true	= RDF::SPARQLResults::Boolean->new( [1] );
	isa_ok( $true, 'RDF::SPARQLResults' );
	is( $true->get_boolean, 1, 'get_boolean' );
	my $false	= RDF::SPARQLResults::Boolean->new( [0] );
	is( $false->get_boolean, 0, 'get_boolean' );
}

{
	my @data	= (
					{ name => 'alice', url => 'http://example.com/alice', number => 1 },
					{ name => 'eve', url => 'http://example.com/eve', number => 2 }
				);
	my $stream	= RDF::SPARQLResults::Bindings->new( \@data, [qw(name url number)] );
	my $pstream	= $stream->project( qw(name number) );
	
	my @cols	= $pstream->binding_names;
	is_deeply( \@cols, [qw(name number)], 'project: binding_names' );
	
	my $alice	= $pstream->next;
	is_deeply( $alice, { name => 'alice', number => 1 }, 'project: alice' );
	
	my $eve		= $pstream->next;
	is_deeply( $eve, { name => 'eve', number => 2 }, 'project: eve' );
	
	my $end		= $pstream->next;
	is( $end, undef, 'project: end' );
}

{
	my $stream	= RDF::SPARQLResults::Bindings->new( [], [qw(name url number)] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, [], 'sorted empty' );
}

{
	my $stream	= RDF::SPARQLResults::Bindings->new( [], [qw(name url number)], sorted_by => ['number'] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, ['number'], 'sorted array' );
}

{
	my $stream	= RDF::SPARQLResults::Bindings->new( [], [qw(name url number)], sorted_by => ['number'] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, ['number'], 'sorted array' );
}
