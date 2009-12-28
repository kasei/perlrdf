#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 8;

use RDF::Trine;
use RDF::Trine::Node;
use_ok( 'RDF::Trine::Iterator::Bindings' );

{
	my $iter	= RDF::Trine::Iterator::Bindings->new();
	is( $iter->next, undef, 'empty iterator' );
}

{
	my @values	= (1,2);
	my $sub		= sub { return shift(@values) };
	my $iter	= RDF::Trine::Iterator::Bindings->new( $sub );
	is( $iter->next, 1 );
	is( $iter->next, 2 );
	is( $iter->next, undef );
}

{
	my @bindings	= (
		{ qw( a 1 b 2 ) },
		{ qw( b 3 c 4 ) },
	);
	my $iter	= RDF::Trine::Iterator::Bindings->new( sub { return shift(@bindings) } );
	my $proj	= $iter->project( 'b' );
	is_deeply( $proj->next, { b => 2 } );
	is_deeply( $proj->next, { b => 3 } );
	is( $proj->next, undef );
}
