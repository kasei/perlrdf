use Test::More; # tests => 14;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Test::Deep;
use Scalar::Util qw(refaddr);
use List::Util qw(shuffle);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level   => $TRACE } ) if $ENV{TEST_VERBOSE};


use RDF::Trine qw(statement iri literal blank variable);

use RDF::Trine::Namespace;
use RDF::Trine::Pattern;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $dct	= RDF::Trine::Namespace->new('http://purl.org/dc/terms/');


note 'Testing Heuristic SPARQL Planner implementation';

{
	my $name = 'two-variable';
	my $in = RDF::Trine::Pattern->new(statement(variable('v1'), $foaf->name, variable('v2')),
												 statement(variable('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(variable('v1'), $rdf->type, $foaf->Person),
												 statement(variable('v1'), $foaf->name, variable('v2')));

	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 1, 'Single entry for ' . $name );
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for ' . $name );
	cmp_bag([$subgrouping[0]->triples], [$in->triples] , 'Just the same for ' . $name );
	is_deeply($in->sort_triples, $re, 'First entry the same for ' . $name );
	is_deeply($subgrouping[0]->sort_triples, $re, 'Grouped first entry the same for ' . $name );
	is_deeply($in->sort_for_join_variables, $re, 'Final sort: Ffirst triple pattern' . $name );
}


{
	my $name = 'two-variable with blank';
	my $in = RDF::Trine::Pattern->new(statement(blank('v1'), $foaf->name, variable('v2')),
												 statement(blank('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(blank('v1'), $rdf->type, $foaf->Person),
												 statement(blank('v1'), $foaf->name, variable('v2')));
	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 1, 'Single entry for ' . $name );
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for ' . $name );
	cmp_bag([$subgrouping[0]->triples], [$in->triples] , 'Just the same for ' . $name );
	is_deeply($in->sort_triples, $re, 'First entry the same for ' . $name );
	is_deeply($subgrouping[0]->sort_triples, $re, 'Grouped first entry the same for ' . $name );
	is_deeply($in->sort_for_join_variables, $re, 'Final sort: Variable and blank node in first triple pattern');
}

{
	my $in = RDF::Trine::Pattern->new(statement(variable('jrn1'), $dct->revised, variable('rev')),
												 statement(variable('jrn1'), $foaf->maker, variable('author')),
												 statement(variable('jrn1'), $dct->title, literal("Journal 1 (1940)")),
												 statement(variable('author'), $foaf->name, variable('name')),
												 statement(variable('jrn1'), $dct->issued, variable('iss')),
												 statement(variable('jrn1'), $rdf->type, $foaf->Document)
												 );
	my $re = RDF::Trine::Pattern->new(
												 statement(variable('jrn1'), $dct->title, literal("Journal 1 (1940)")),
												 statement(variable('jrn1'), $rdf->type, $foaf->Document),
												 statement(variable('jrn1'), $dct->issued, variable('iss')),
												 statement(variable('jrn1'), $dct->revised, variable('rev')),
												 statement(variable('jrn1'), $foaf->maker, variable('author')),
												 statement(variable('author'), $foaf->name, variable('name')),
												 );
	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 2, 'Two entries for large star with one chain');
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for large star with one chain');
	my @firstgroup = $re->triples;
	my $manualgroup = RDF::Trine::Pattern->new(@firstgroup[0..4]);
	is_deeply($subgrouping[0]->sort_triples, $manualgroup, 'First group has the correct sort ');

	is_deeply($in->sort_for_join_variables, $re, 'Final sort: Large star and one chain');
}
{
	my $name = 'two connected stars';
	my $in = RDF::Trine::Pattern->new(
												 statement(variable('author'), $foaf->member, iri('http://example.org')),
												 statement(variable('person'), $foaf->name, literal('Someone')),
												 statement(variable('author'), $foaf->name, variable('name')),
												 statement(variable('jrn1'), $dct->revised, variable('rev')),
												 statement(variable('jrn1'), $foaf->maker, variable('author')),
												 statement(variable('jrn1'), $rdf->type, $foaf->Document),
												 statement(variable('jrn1'), $dct->title, literal("Journal 1 (1940)")),
												 statement(variable('author'), $foaf->knows, variable('person')),
												);
	my $re = RDF::Trine::Pattern->new(
												 statement(variable('jrn1'), $dct->title, literal("Journal 1 (1940)")),
												 statement(variable('jrn1'), $rdf->type, $foaf->Document),
												 statement(variable('jrn1'), $dct->revised, variable('rev')),
												 statement(variable('jrn1'), $foaf->maker, variable('author')),
												 statement(variable('author'), $foaf->member, iri('http://example.org')),
												 statement(variable('author'), $foaf->name, variable('name')),
												 statement(variable('author'), $foaf->knows, variable('person')),
												 statement(variable('person'), $foaf->name, literal('Someone'))
												);
	my @subgrouping = $in->subgroup;

	is(scalar @subgrouping, 3, 'Three entries for ' . $name);
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for ' . $name);

	my @intriples = $in->triples;
	my $ingroups = [ RDF::Trine::Pattern->new(@intriples[3 .. 6]),
						  RDF::Trine::Pattern->new(@intriples[0,2,7]),
						  RDF::Trine::Pattern->new($intriples[1]) ];
	my @retriples = $re->triples;
	my $regroups = [ RDF::Trine::Pattern->new(@retriples[0 .. 3]),
						  RDF::Trine::Pattern->new(@retriples[4 .. 6]),
						  RDF::Trine::Pattern->new($retriples[7]) ];
	cmp_bag([$subgrouping[0]->triples], [$ingroups->[0]->triples] , '1st pattern for ' . $name );
	cmp_bag([$subgrouping[1]->triples], [$ingroups->[1]->triples] , '2st pattern for ' . $name );
	cmp_bag([$subgrouping[2]->triples], [$ingroups->[2]->triples] , '3st pattern for ' . $name );

	is_deeply($subgrouping[0]->sort_triples, $regroups->[0], '1st group has the correct sort in ' . $name);
	is_deeply($subgrouping[1]->sort_triples, $regroups->[1], '2st group has the correct sort in ' . $name);
	is_deeply($subgrouping[2]->sort_triples, $regroups->[2], '3st group has the correct sort in ' . $name);

	my @sortgroups = ( $subgrouping[0]->sort_triples,
							 $subgrouping[1]->sort_triples,
							 $subgrouping[2]->sort_triples );

	my $merge = RDF::Trine::Pattern->merge_patterns(@sortgroups);
	isa_ok($merge, 'RDF::Trine::Pattern');

	is_deeply($merge, $re, 'Sort with manual process in ' . $name);

	is_deeply($in->sort_for_join_variables, $re, 'Final sort: ' . $name);
}

{
	# Using no common terms to test only heuristic 1
	my $name = 'random';
	my $spo = statement(iri('http://example.org/someone#1'), $foaf->page, iri('http://example.org/'));
	my $svo = statement(iri('http://example.com/someone#2'), variable('v1'), literal('foo1'));
	my $vpo = statement(variable('v2'), $foaf->name, literal('foo2'));
	my $spv = statement(iri('http://example.com/someone#3'), $foaf->gender, variable('v3'));
	my $vvo = statement(variable('v4'), variable('v5'), literal('foo3'));
	my $svv = statement(iri('http://example.com/someone#3'), variable('v6'), variable('v7'));
	my $vpv = statement(variable('v8'), $foaf->homepage, variable('v9'));
	my $vvv = statement(variable('v10'), variable('v11'), variable('v12'));
	my @statements = ($spo,$svo,$vpo,$spv,$vvo,$svv,$vpv,$vvv);
	my @reorder = shuffle(@statements);
	my $in = RDF::Trine::Pattern->new(@reorder);
	my $re = RDF::Trine::Pattern->new(@statements);
	my @subgrouping = $in->subgroup;

	is(scalar @subgrouping, 1, 'Single entry for ' . $name );
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for ' . $name );
	cmp_bag([$subgrouping[0]->triples], [$in->triples] , 'Just the same for ' . $name );
	is_deeply($in->sort_triples, $re, 'First entry the same for ' . $name );
	is_deeply($subgrouping[0]->sort_triples, $re, 'Grouped first entry the same for ' . $name );

	my $got = $in->sort_for_join_variables;

	is_deeply($got, $re, 'Final sort: All possible triple patterns in random order');
}



done_testing;
