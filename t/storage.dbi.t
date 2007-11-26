#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Test::More qw(no_plan);
use Test::Exception;

use_ok( 'RDF::Base::Storage::DBI' );

my $dbi	= RDF::Base::Storage::DBI->new();
isa_ok( $dbi, 'RDF::Base::Storage::DBI' );

{
	my $value	= 'Rhttp://xmlns.com/foaf/0.1/name';
	my $hash	= RDF::Base::Storage::DBI::_mysql_hash( $value );
	is( $hash, '14911999128994829034', 'value hash' );
}

{
	my $uri		= 'http://xmlns.com/foaf/0.1/name';
	my $node	= RDF::Query::Node::Resource->new( uri => $uri );
	my $hash	= RDF::Base::Storage::DBI::_mysql_node_hash( $node );
	is( $hash, '14911999128994829034', 'uri hash' );
}

my $greg;

{
	my $s	= RDF::Query::Node::Blank->new();
	$greg	= $s;	# save this node for later
	my $p	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' );
	my $o	= RDF::Query::Node::Literal->new( value => 'greg' );
	my $st	= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o );
	$dbi->add_statement( $st );
	is( $dbi->count_statements, 1, 'statement count' );
}

{
	my $s	= RDF::Query::Node::Blank->new();
	my $p	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $o	= RDF::Query::Node::Literal->new( value => 'ubu' );
	my $st	= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o );
	$dbi->add_statement( $st );
	is( $dbi->count_statements, 2, 'statement count' );
}

{
	my $p		= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $stream	= $dbi->get_statements(undef, $p, undef);
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
	my $stream	= $dbi->get_statements();
	my $count	= 0;
	while ($stream->next()) { $count++ }
	is( $count, 2, 'two statements expected' );
}

{
	my $subj	= RDF::Query::Node::Variable->new( name => 'foo' );
	my $pred	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $obj		= RDF::Query::Node::Variable->new( name => 'bar' );
	my $triple	= RDF::Base::Statement->new( subject => $subj, predicate => $pred, object => $obj );
	my $stream	= $dbi->multi_get( triples => [ $triple ] );
	
	my $data	= $stream->next;
	is( reftype($data), 'HASH' );
	
	my $person	= $data->{foo};
	my $nick	= $data->{bar};
	
	isa_ok( $person, 'RDF::Query::Node::Blank' );
	isa_ok( $nick, 'RDF::Query::Node::Literal' );
	is( $nick->literal_value, 'ubu', 'expected literal value' );
}

{
	use utf8;
	my $kasei	= RDF::Query::Node::Literal->new( value => '火星', language => 'ja' );
	my $nick	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
	my $st		= RDF::Base::Statement->new( subject => $greg, predicate => $nick, object => $kasei );
	$dbi->add_statement( $st );
	
	my $person	= RDF::Query::Node::Variable->new( name => 'foo' );
	my $var		= RDF::Query::Node::Variable->new( name => 'bar' );
	my $literal	= RDF::Query::Node::Literal->new( value => 'greg' );
	my $name	= RDF::Query::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' );
	my $triple1	= RDF::Base::Statement->new( subject => $person, predicate => $name, object => $literal );
	my $triple2	= RDF::Base::Statement->new( subject => $person, predicate => $nick, object => $var );
	my $stream	= $dbi->multi_get( triples => [ $triple1, $triple2 ] );
	
	my $data	= $stream->next;
	is( reftype($data), 'HASH' );
	
	{
		my $person	= $data->{foo};
		my $nick	= $data->{bar};
		
		isa_ok( $person, 'RDF::Query::Node::Blank' );
		isa_ok( $nick, 'RDF::Query::Node::Literal' );
		is( $nick->literal_value, "火星", 'expected multi-get nickname value' );
		is( $nick->language, 'ja', 'expected multi-get nickname language' );
	}
}
