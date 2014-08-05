use Test::More;
use Test::JSON;

use strict;
use warnings;
no warnings 'redefine';

use URI::file;

use RDF::Trine qw(statement iri literal variable);
use RDF::Trine::Node;
use_ok( 'RDF::Trine::Iterator::Bindings' );

{
	my $iter	= RDF::Trine::Iterator::Bindings->new();
	is( $iter->next, undef, 'empty iterator' );
}

{
	note('simple values');
	my @values	= (1,2);
	my $sub		= sub { return shift(@values) };
	my $iter	= RDF::Trine::Iterator::Bindings->new( $sub );
	is( $iter->next, 1 );
	is( $iter->next, 2 );
	is( $iter->next, undef );
}

{
	note('hash values');
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
	note('as_json with empty iterator, no variables');
	my $iter	= RDF::Trine::Iterator::Bindings->new( [] );
	my $expect	= '{"head":{"vars":[]},"results":{"bindings":[],"distinct":false,"ordered":false}}';
	is_json( $iter->as_json, $expect, 'as_json empty bindings iterator without names' );
}

{
	note('as_json with empty iterator, 3 variables');
	my $iter	= RDF::Trine::Iterator::Bindings->new( [], [qw(a b c)] );
	my $expect	= '{"head":{"vars":["a", "b", "c"]},"results":{"bindings":[],"distinct":false,"ordered":false}}';
	is_json( $iter->as_json, $expect, 'as_json empty bindings iterator with names' );
}

{
	my $t1		= statement(variable('subj'), iri('pred1'), literal('foo'));
	my $t2		= statement(variable('subj'), iri('pred2'), variable('obj'));
	my $pattern	= RDF::Trine::Pattern->new($t1, $t2);
	my @bindings	= (
		{ 'subj' => iri('http://example.org/x1') },
		{ 'subj' => iri('http://example.org/x2'), 'obj' => literal('bar') },
	);
	my $iter	= RDF::Trine::Iterator::Bindings->new( sub { return shift(@bindings) } );
	my $sts		= $iter->as_statements($pattern);
	my @triples	= $sts->get_all;
	is(scalar(@triples), 3, 'expected triple count from as_statements with pattern');
	
	ok(
		$triples[0]->subsumes(
			statement(iri('http://example.org/x1'), iri('pred1'), literal('foo'))
		),
		'expected triple 1/3'
	);
	
	ok(
		$triples[1]->subsumes(
			statement(iri('http://example.org/x2'), iri('pred1'), literal('foo'))
		),
		'expected triple 2/3'
	);
	
	ok(
		$triples[2]->subsumes(
			statement(iri('http://example.org/x2'), iri('pred2'), literal('bar'))
		),
		'expected triple 3/3'
	);
}

done_testing();
