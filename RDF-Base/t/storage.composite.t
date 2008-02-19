#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Test::More qw(no_plan);
use Test::Exception;

use RDF::Base::Namespace;
use RDF::Base::Storage::DBI;
use RDF::Base::Storage::Memory;
use_ok( 'RDF::Base::Storage::Composite' );

throws_ok { RDF::Base::Storage::Composite->new() } 'Error';
throws_ok { RDF::Base::Storage::Composite->new( backends => [] ) } 'Error';

my $foaf	= RDF::Base::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
my $dbi		= RDF::Base::Storage::DBI->new();
my $memory	= RDF::Base::Storage::Memory->new();

my $greg	= RDF::Query::Node::Blank->new();
{
	my $s	= $greg;
	my $p	= $foaf->name;
	my $o	= RDF::Query::Node::Literal->new( value => 'greg' );
	my $st	= RDF::Base::Statement->new( subject => $greg, predicate => $p, object => $o );
	$dbi->add_statement( $st );
	is( $dbi->count_statements, 1, 'statement count' );
}

{
	my $p	= $foaf->nick;
	my $o	= RDF::Query::Node::Literal->new( value => 'ubu' );
	my $st	= RDF::Base::Statement->new( subject => $greg, predicate => $p, object => $o );
	$memory->add_statement( $st );
	is( $memory->count_statements, 1, 'statement count' );
}


my $storage	= RDF::Base::Storage::Composite->new( backends => [ $memory, $dbi ] );
isa_ok( $storage, 'RDF::Base::Storage::Composite' );


{
	my $p		= $foaf->nick;
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
	while ($stream->next()) { $count++ }
	is( $count, 2, 'two statements expected' );
}

{
	use utf8;
	my $kasei	= RDF::Query::Node::Literal->new( value => '火星', language => 'ja' );
	my $nick	= $foaf->nick;
	my $st		= RDF::Base::Statement->new( subject => $greg, predicate => $nick, object => $kasei );
	$dbi->add_statement( $st );
	is( $memory->count_statements, 1, 'statement count after composite-add' );
	is( $dbi->count_statements, 2, 'statement count after composite-add' );
}

{
	my $p		= $foaf->nick;
	my $stream	= $storage->get_statements(undef, $p, undef);
	my $count	= 0;
	while ($stream->next()) { $count++ }
	is( $count, 2, 'two statements expected' );
}
