#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 21;
use Test::Exception;

use Data::Dumper;
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Statement;

my $p1		= RDF::Trine::Node::Resource->new('http://example.org/alice');
my $p2		= RDF::Trine::Node::Resource->new('http://example.org/eve');
my $p3		= RDF::Trine::Node::Resource->new('http://example.org/bob');
my $type	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
my $person	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/Person');

my $st1		= RDF::Trine::Statement->new( $p1, $type, $person );
my $st2		= RDF::Trine::Statement->new( $p2, $type, $person );
my $st3		= RDF::Trine::Statement->new( $p3, $type, $person );

{
	my $stream	= RDF::Trine::Iterator::Graph->new();
	isa_ok( $stream, 'RDF::Trine::Iterator::Graph' );
	ok( $stream->is_graph, 'is_graph' );
	my $data	= $stream->next;
	is( $data, undef );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3 ] );
	isa_ok( $stream, 'RDF::Trine::Iterator::Graph' );
	my $st		= $stream->next;
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

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3 ] );
	my @vars		= map { RDF::Trine::Node::Variable->new( $_ ) } qw(s p o);
	my $bindings	= $stream->as_bindings( @vars );
	isa_ok( $bindings, 'RDF::Trine::Iterator::Bindings' );
	my $hash		= $bindings->next;
	isa_ok( $hash, 'HASH' );
	is_deeply( $hash, { 's' => $p1, p => $type, o => $person } );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st1, $st3, $st2, $st1 ] );
	my $unique	= $stream->unique;
	isa_ok( $unique, 'RDF::Trine::Iterator::Graph' );
	my $count	= 0;
	while (my $st = $unique->next) {
		$count++;
	}
	is( $count, 3, 'graph iterator unique' );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2 ] );
	my $xml		= $stream->as_xml;
	like( $xml, qr<rdf:Description.*http://example.org/alice.*type.*http://xmlns.com/foaf/0.1/Person>sm, 'graph iterator as_xml' );
	like( $xml, qr<http://example.org/eve>sm, 'graph iterator as_xml (second result)' );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2 ] );
	my $xml		= $stream->as_xml( 2 );
	my @matches	= ($xml =~ m<"http://example.org/([^"]+)">gsm);
	is( scalar(@matches), 2, 'graph iterator as_xml maxcount=2' );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2 ] );
	my $xml		= $stream->as_xml( 1 );
	my @matches	= ($xml =~ m<"http://example.org/([^"]+)">gsm);
	is( scalar(@matches), 1, 'graph iterator as_xml maxcount=1' );
}

{
	my $stream	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2 ] );
	throws_ok {
		my $json	= $stream->as_json;
	} 'RDF::Trine::Error::SerializationError';
}

{
	my $stream1	= RDF::Trine::Iterator::Graph->new( [ $st2, $st3 ] );
	my $stream2	= RDF::Trine::Iterator::Graph->new( [ $st1, $st3 ] );
	my $mstream = $stream1->concat($stream2)->materialize;
	is($mstream->length, 4, 'Concatenated Graph Iterator has 4 statements');
	$mstream->reset;
	is($mstream->unique->length, 3, 'Concatenated Graph Iterator has 3 unique statements');
}
