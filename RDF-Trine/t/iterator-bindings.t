use Test::More tests => 10;
use Test::JSON;

use strict;
use warnings;
no warnings 'redefine';

use URI::file;

use RDF::Trine;
use_ok( 'RDF::Trine::Iterator::Bindings' );

{
	my $iter	= RDF::Trine::Iterator::Bindings->new();
	is( $iter->next, undef, 'empty iterator' );
}

{
	diag('simple values');
	my @values	= (1,2);
	my $sub		= sub { return shift(@values) };
	my $iter	= RDF::Trine::Iterator::Bindings->new( $sub );
	is( $iter->next, 1 );
	is( $iter->next, 2 );
	is( $iter->next, undef );
}

{
	diag('hash values');
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

{
	diag('as_json with empty iterator, no variables');
	my $iter	= RDF::Trine::Iterator::Bindings->new( [] );
	my $expect	= '{"head":{"vars":[]},"results":{"bindings":[],"distinct":false,"ordered":false}}';
	is_json( $iter->as_json, $expect, 'as_json empty bindings iterator without names' );
}

{
	diag('as_json with empty iterator, 3 variables');
	my $iter	= RDF::Trine::Iterator::Bindings->new( [], [qw(a b c)] );
	my $expect	= '{"head":{"vars":["a", "b", "c"]},"results":{"bindings":[],"distinct":false,"ordered":false}}';
	is_json( $iter->as_json, $expect, 'as_json empty bindings iterator with names' );
}
