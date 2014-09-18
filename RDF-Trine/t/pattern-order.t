use Test::More; # tests => 14;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);
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
	my $in = RDF::Trine::Pattern->new(statement(variable('v1'), $foaf->name, variable('v2')),
												 statement(variable('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(variable('v1'), $rdf->type, $foaf->Person),
												 statement(variable('v1'), $foaf->name, variable('v2')));

	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 1, 'Single entry for two-variable');
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for two-variable');
	is_deeply($subgrouping[0], $in, 'Just the same for two-variable');
	is_deeply($in->sort_for_join_variables, $re, 'Two variables in first triple pattern');
}


{
	my $in = RDF::Trine::Pattern->new(statement(blank('v1'), $foaf->name, variable('v2')),
												 statement(blank('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(blank('v1'), $rdf->type, $foaf->Person),
												 statement(blank('v1'), $foaf->name, variable('v2')));
	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 1, 'Single entry for two-variable with blank');
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for two-variable with blank');
	is_deeply($subgrouping[0], $in, 'Just the same for two-variable with blank');
	is_deeply($in->sort_for_join_variables, $re, 'Variable and blank node in first triple pattern');
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
#	is_deeply($subgrouping[0], $in, 'Just the same for two-variable with blank');

	is_deeply($in->sort_for_join_variables, $re, 'Large star and one chain');
}
{
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
	is(scalar @subgrouping, 3, 'Three entries for two connected stars');
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for two connected stars');
#	is_deeply($subgrouping[0], $in, 'Just the same for two-variable with blank');

	is_deeply($in->sort_for_join_variables, $re, 'Two connected stars');
}

# TODO: What to do if no definite variables?

{
	# Using no common terms to test only heuristic 1
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
	my @subgrouping = $in->subgroup;
	is(scalar @subgrouping, 1, 'Single large entry for random');
	isa_ok(\@subgrouping, 'ARRAY', 'Subgroup produces array for random');
	is_deeply($subgrouping[0], $in, 'Just the same for random');

	my $re = RDF::Trine::Pattern->new(@statements);
	my $got = $in->sort_for_join_variables;

	is_deeply($got, $re, 'All possible triple patterns in random order');
}



done_testing;
