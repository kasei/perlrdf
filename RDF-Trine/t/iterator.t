#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 65;
use Scalar::Util qw(reftype);

use Data::Dumper;
use RDF::Trine qw(iri literal);
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;

{
	my $iter	= RDF::Trine::Iterator->new([1,2]);
	is( &$iter, 1 );
	is( $iter->next, 2 );
	is( &$iter, undef );
}

{
	my @data	= ({value=>1},{value=>2},{value=>3});
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@data, [qw(value)] );
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	ok( $stream->is_bindings, 'is_bindings' );
	is( $stream->is_boolean, 0, 'is_boolean' );
	is( $stream->is_graph, 0, 'is_graph' );
	
	my @values	= $stream->get_all;
	is_deeply( \@values, [{value=>1}, {value=>2}, {value=>3}], 'deep comparison' );
}

{
	my @data	= ({value=>1},{value=>2},{value=>3});
	my $stream	= smap { $_->{value}++; $_ } RDF::Trine::Iterator::Bindings->new( \@data, [qw(value)] );
	isa_ok( $stream, 'RDF::Trine::Iterator::Bindings' );
	my @values	= $stream->get_all;
	is_deeply( \@values, [{value=>2}, {value=>3}, {value=>4}], 'smap increment' );
}

{
	my @first	= ({value=>1},{value=>2});
	my @second	= ({value=>3});
	
	my $data	= RDF::Trine::Iterator::Bindings->new( \@first, [qw(value)] );
	my $extra	= RDF::Trine::Iterator::Bindings->new( \@second, [qw(value)] );
	
	my $stream	= $data->concat( $extra );
	
	isa_ok( $stream, 'RDF::Trine::Iterator' );
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
		my $stream	= RDF::Trine::Iterator::Bindings->new( $data, [qw(value)] );
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
	my $true	= RDF::Trine::Iterator::Boolean->new( [1] );
	isa_ok( $true, 'RDF::Trine::Iterator' );
	is( $true->get_boolean, 1, 'get_boolean' );
	my $false	= RDF::Trine::Iterator::Boolean->new( [0] );
	is( $false->get_boolean, 0, 'get_boolean' );
}

{
	my @data	= (
					{ name => 'alice', url => 'http://example.com/alice', number => 1 },
					{ name => 'eve', url => 'http://example.com/eve', number => 2 }
				);
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@data, [qw(name url number)] );
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
	my $stream	= RDF::Trine::Iterator::Bindings->new( [], [qw(name url number)] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, [], 'sorted empty' );
}

{
	my $stream	= RDF::Trine::Iterator::Bindings->new( [], [qw(name url number)], sorted_by => ['number' => 'ASC'] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, ['number' => 'ASC'], 'sorted array' );
}

{
	my $stream	= RDF::Trine::Iterator::Bindings->new( [], [qw(name url number)], sorted_by => ['number' => 'ASC', name => 'DESC'] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, [qw(number ASC name DESC)], 'sorted array' );
}

{
	my $count	= 0;
	my $stream	= swatch { $count++ } sgrep { $_->{number} % 2 == 0 } RDF::Trine::Iterator::Bindings->new( [{ name => 'Alice', number => 1}, { name => 'Eve', number => 2 }], [qw(name url number)], sorted_by => ['number' => 'ASC', name => 'DESC'] );
	my @sort	= $stream->sorted_by;
	is_deeply( \@sort, [qw(number ASC name DESC)], 'sorted array' );
	is( $count, 0, 'zero watched results' );
	my $row		= $stream->next;
	is_deeply( $row, { name => 'Eve', number => 2 }, 'expected result after sgrep' );
	is( $count, 1, 'one watched result' );
	is( $stream->next, undef, 'empty stream' );
}

{
	my @data	= (
					RDF::Trine::VariableBindings->new({ name => literal('alice'), url => iri('http://example.com/alice'), number => literal(1) }),
					RDF::Trine::VariableBindings->new({ name => literal('eve'), url => iri('http://example.com/eve'), number => literal(2) }),
				);
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@data, [qw(name url number)] );
	my $string	= $stream->to_string();
	like( $string, qr/<\?xml/, 'xml to_string serialization' );
}

{
	my $xml	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="name"/>
	<variable name="url"/>
	<variable name="number"/>
</head>
<results>
		<result>
			<binding name="name"><literal>alice</literal></binding>
			<binding name="url"><uri>http://example.com/alice</uri></binding>
			<binding name="number"><literal>1</literal></binding>
		</result>
		<result>
			<binding name="name"><literal>eve</literal></binding>
			<binding name="url"><uri>http://example.com/eve</uri></binding>
			<binding name="number"><literal>2</literal></binding>
		</result>
</results>
</sparql>
END
	my $iter	= RDF::Trine::Iterator->from_string( $xml );
	is_deeply( [$iter->construct_args], ['bindings', [qw(name url number)]], 'expected construct args' );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	my $b		= $iter->next;
	is( reftype($b), 'HASH', 'expected variable bindings HASH' );
	is( $b->{name}->literal_value, 'alice', 'expected variable binding literal value' );
}
