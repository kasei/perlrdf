#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 5;

use Data::Dumper;
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;

{
	my @data	= ({value=>1},{value=>2},{value=>3});
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@data, [qw(value)] );
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	my $m		= $stream->materialize;
	isa_ok( $m, 'RDF::Trine::Iterator::Bindings::Materialized' );
	
	my $data	= $m->next;
	is( $data->{value}, 1, 'first value' );
	
	$m->reset;
	for (qw(first second)) {
		my @values	= $m->get_all;
		is_deeply( \@values, [{value=>1}, {value=>2}, {value=>3}], "deep comparison ($_ run)" );
	}
}

