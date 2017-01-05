#!/usr/bin/env perl

use strict;
use warnings;
use blib;
use Data::Dumper;

use RDF::Trine;
use RDF::Trine::Store::B;

my $b	= RDF::Trine::Store::B->new('/tmp/triplestore');

my $s	= RDF::Trine::Node::Resource->new('http://www.Department0.University0.edu/AssistantProfessor9');
my $p	= RDF::Trine::Node::Resource->new('http://www.lehigh.edu/%7Ezhp2/2004/0401/univ-bench.owl#mastersDegreeFrom');
my $o	= undef; #RDF::Trine::Node::Resource->new('http://www.University367.edu');

my $i	= $b->find_statements( $s, $p, $o );
#my $i	= $b->iterate;

while (my $t = $i->next) {
	my $st	= RDF::Trine::Statement->new(
		$t->subject,
		$t->predicate,
		$t->object,
	);
	print "OBJECT: " . $st->as_string . "\n";
}

