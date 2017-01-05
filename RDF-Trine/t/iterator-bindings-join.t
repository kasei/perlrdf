#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 17;

use RDF::Trine;
use RDF::Trine::Node;
use_ok( 'RDF::Trine::Iterator' );

# something like { ?p a foaf:Person ; foaf:name ?n }
my $p1	= RDF::Trine::Node::Resource->new('http://example.org/alice');
my $p2	= RDF::Trine::Node::Resource->new('http://example.org/eve');
my $p3	= RDF::Trine::Node::Resource->new('http://example.org/bob');

my $n1	= RDF::Trine::Node::Literal->new('Alice');
my $n1a	= RDF::Trine::Node::Literal->new('Alice', 'en');
my $n2	= RDF::Trine::Node::Literal->new('Eve');
my $n3	= RDF::Trine::Node::Literal->new('Bob');

{
	my @people	= (
					{ p => $p1 },
					{ p => $p2 },
					{ p => $p3 },
				);
	my @names	= (
					{ p => $p3, n => $n3 },
					{ p => $p1, n => $n1a },
					{ p => $p2, n => $n2 },
					{ p => $p1, n => $n1 },
				);
	
	{
		print "# nested loop join outer order (1)\n";
		my $people	= RDF::Trine::Iterator::Bindings->new( [@people], ['p'] );
		my $names	= RDF::Trine::Iterator::Bindings->new( [@names], ['p', 'n'] );
		my $join	= RDF::Trine::Iterator::Bindings->join_streams( $people, $names );
		isa_ok( $join, 'RDF::Trine::Iterator::Bindings' );
		
		my @expect	= (qw(Alice Alice Eve Bob));
		while (my $row = $join->next) {
			my $e		= shift(@expect);
			my $name	= $row->{n};
			is( $name->literal_value, $e, 'expected name' );
		}
		
	}
	
	{
		print "# nested loop join outer order (2)\n";
		my $people	= RDF::Trine::Iterator::Bindings->new( [@people], ['p'] );
		my $names	= RDF::Trine::Iterator::Bindings->new( [@names], ['p', 'n'] );
		my $join	= RDF::Trine::Iterator::Bindings->join_streams( $names, $people );
		isa_ok( $join, 'RDF::Trine::Iterator::Bindings' );
		
		my @expect	= (qw(Bob Alice Eve Alice));
		while (my $row = $join->next) {
			my $e		= shift(@expect);
			my $name	= $row->{n};
			is( $name->literal_value, $e, 'expected name' );
		}
		
	}
}

{
	my @people	= (
					{ p => $p1 },
					{ p => $p2 },
				);
	my @names	= (
					{ n => $n2 },
					{ n => $n1 },
				);
	
	{
		print "# nested loop join for cartesian product\n";
		my $people	= RDF::Trine::Iterator::Bindings->new( [@people], ['p'] );
		my $names	= RDF::Trine::Iterator::Bindings->new( [@names], ['n'] );
		my $join	= RDF::Trine::Iterator::Bindings->join_streams( $people, $names );
		my $stream	= $join->materialize;
		isa_ok( $stream, 'RDF::Trine::Iterator::Bindings' );
		is( $stream->length, 4, 'cartesian product size' );
		
		my %counts;
		while (my $row = $stream->next) {
			$counts{ $row->{p}->as_string }++;
			$counts{ $row->{n}->as_string }++;
		}
		is( $counts{ '<http://example.org/alice>' }, 2, 'expected tuple count for <alice>' );
		is( $counts{ '"Alice"' }, 2, 'expected tuple count for "alice"' );
		is( $counts{ '<http://example.org/eve>' }, 2, 'expected tuple count for <eve>' );
		is( $counts{ '"Eve"' }, 2, 'expected tuple count for "Eve"' );
	}
}
__END__
