use Test::More; # tests => 14;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);
use List::Util qw(shuffle);

use RDF::Trine qw(statement iri literal blank variable);

use RDF::Trine::Namespace;
use RDF::Trine::Pattern;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');

note 'Testing Heuristic SPARQL Planner implementation';

{
	my $in = RDF::Trine::Pattern->new(statement(variable('v1'), $foaf->name, variable('v2')),
												 statement(variable('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(variable('v1'), $rdf->type, $foaf->Person),
												 statement(variable('v1'), $foaf->name, variable('v2')));
	is_deeply($in, $re->sort_for_join_variables, 'Two variables in first triple pattern');
}


{
	my $in = RDF::Trine::Pattern->new(statement(blank('v1'), $foaf->name, variable('v2')),
												 statement(blank('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(blank('v1'), $rdf->type, $foaf->Person),
												 statement(blank('v1'), $foaf->name, variable('v2')));
	is_deeply($in, $re->sort_for_join_variables, 'Variable and blank node in first triple pattern');
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
	my $re = RDF::Trine::Pattern->new(@statements);
	is_deeply($in, $re->sort_for_join_variables, 'All possible triple patterns in random order');
}



done_testing;
