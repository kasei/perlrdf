use Test::More; # tests => 14;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);

use RDF::Trine qw(statement iri literal blank variable);

use RDF::Trine::Namespace;
use RDF::Trine::Pattern;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');


{
	my $in = RDF::Trine::Pattern->new(statement(variable('v1'), $foaf->name, variable('v2')),
												 statement(variable('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(variable('v1'), $rdf->type, $foaf->Person),
												 statement(variable('v1'), $foaf->name, variable('v2')));
	is_deeply($in, $re, 'Two variables in first triple pattern');
}


{
	my $in = RDF::Trine::Pattern->new(statement(blank('v1'), $foaf->name, variable('v2')),
												 statement(blank('v1'), $rdf->type, $foaf->Person));	

	my $re = RDF::Trine::Pattern->new(statement(blank('v1'), $rdf->type, $foaf->Person),
												 statement(blank('v1'), $foaf->name, variable('v2')));
	is_deeply($in, $re, 'Variable and blank node in first triple pattern');
}

# TODO: What to do if no definite variables?





done_testing;
