#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 8;

use Data::Dumper;
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Bindings::Materialized;
use RDF::Trine::Statement;

my $p1	= RDF::Trine::Node::Resource->new('http://example.org/alice');
my $p2	= RDF::Trine::Node::Resource->new('http://example.org/eve');
my $p3	= RDF::Trine::Node::Resource->new('http://example.org/bob');

my $n1	= RDF::Trine::Node::Literal->new('Alice');
my $n1a	= RDF::Trine::Node::Literal->new('Alice', 'en');
my $n2	= RDF::Trine::Node::Literal->new('Eve');
my $n3	= RDF::Trine::Node::Literal->new('Bob');

my @bindings	= (
					{ p => $p3, n => $n3 },
					{ p => $p1, n => $n1a },
					{ p => $p2, n => $n2 },
					{ p => $p1, n => $n1 },
				);

{
	my @data	= @bindings;
	my $sub		= sub { shift(@data) };
	my $stream	= RDF::Trine::Iterator::Bindings::Materialized->new( $sub, [qw(p n)] );
	isa_ok( $stream, 'RDF::Trine::Iterator::Bindings::Materialized' );
	is( $stream->length, 4, 'materialized bindings length' );
	
	print "# iterator reset\n";
	$stream->reset;
	my @expect	= qw(Bob Alice Eve Alice);
	while (my $bind = $stream->next) {
		is( $bind->{n}->literal_value, shift(@expect), 'expected literal value' );
	}
	
	print "# iterator reset\n";
	$stream->reset;
	my $bind	= $stream->next;
	isa_ok( $bind, 'HASH' );
	is( $bind->{n}->literal_value, 'Bob', 'expected literal value' );
}
