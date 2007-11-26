#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Test::More qw(no_plan);
use Test::Exception;

use RDF::Base::Statement;
use_ok( 'RDF::Base::Storage::Memory' );

my $storage	= RDF::Base::Storage::Memory->new();
isa_ok( $storage, 'RDF::Base::Storage::Memory' );

my $greg;

{
	my $s	= RDF::Query::Node::Blank->new();
	$greg	= $s;	# save this node for later
	my $p	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' );
	my $o	= RDF::Query::Node::Literal->new( value => 'greg' );
	my $st	= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o );
	$storage->add_statement( $st );
	is( $storage->count_statements, 1, 'statement count' );
	ok( $storage->exists_statement( $st ), 'exists_statement' );
	ok( $storage->exists_statement( $s, $p, $o ), 'exists_statement' );
}

{
	my $s	= RDF::Query::Node::Blank->new();
	my $p	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $o	= RDF::Query::Node::Literal->new( value => 'ubu' );
	$storage->add_statement( $s, $p, $o );
	is( $storage->count_statements, 2, 'statement count' );
}

{
	my $p		= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $stream	= $storage->get_statements(undef, $p, undef);
	my $st		= $stream->next;
	isa_ok( $st, 'RDF::Base::Statement' );
	my $o		= $st->object;
	isa_ok( $o, 'RDF::Query::Node::Literal' );
	is( $o->literal_value, 'ubu', 'expected literal value' );
	ok( not($o->language), 'no language expected' );
	ok( not($o->datatype), 'no datatype expected' );
	
	is( $stream->next, undef, 'empty stream' );
}

{
	my $stream	= $storage->get_statements();
	my $count	= 0;
	while (my $st = $stream->next()) {
		$count++
	}
	is( $count, 2, 'two statements expected' );
}

{
	my $b		= $greg->name;
	my $st		= RDF::Base::Statement->parse( qq#{($b), [http://xmlns.com/foaf/0.1/name], "greg"}# );
	my $count	= $storage->count_statements( $st );
	is( $count, 1, 'one statement expected' );
}

{
	$storage->remove_statement(
		$greg,
		RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' ),
		RDF::Query::Node::Literal->new( value => 'greg' ),
	);
	is( $storage->count_statements, 1, 'statement count' );
}

{
	my $stream	= $storage->get_statements();
	my $count	= 0;
	while (my $st = $stream->next()) {
		$storage->remove_statement( $st );
		$count++
	}
	is( $count, 1, 'remove count' );
	is( $storage->count_statements, 0, 'statement count' );
}

__END__

-*- x-counterpart: ../lib/RDF/Base/Storage.pm; -*-
