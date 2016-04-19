#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 7;

use Data::Dumper;
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Statement;

my $p1		= RDF::Trine::Node::Resource->new('http://example.org/alice');
my $p2		= RDF::Trine::Node::Resource->new('http://example.org/eve');
my $p3		= RDF::Trine::Node::Resource->new('http://example.org/bob');
my $type	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
my $person	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/');

my $st1		= RDF::Trine::Statement->new( $p1, $type, $person );
my $st2		= RDF::Trine::Statement->new( $p2, $type, $person );
my $st3		= RDF::Trine::Statement->new( $p3, $type, $person );

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3 ] );
	my $m		= $stream->materialize;
	isa_ok( $m, 'RDF::Trine::Iterator::Graph::Materialized' );
	is( $m->length, 3 );
	
	$m->reset;
	my $st		= $m->next;
	isa_ok( $st, 'RDF::Trine::Statement' );
	is( $st->subject->uri_value, 'http://example.org/alice' );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3 ] );
	my $bindings	= $stream->as_bindings;
	isa_ok( $bindings, 'RDF::Trine::Iterator::Bindings' );
	my $hash		= $bindings->next;
	isa_ok( $hash, 'HASH' );
	is_deeply( $hash, { subject => $p1, predicate => $type, object => $person } );
}

