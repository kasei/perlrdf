#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use RDF::Base::Statement;

use_ok( 'RDF::Base::Pattern' );
use_ok( 'RDF::Base::Pattern::Filter' );
use_ok( 'RDF::Base::Pattern::Graph' );
use_ok( 'RDF::Base::Pattern::Optional' );
use_ok( 'RDF::Base::Pattern::Triples' );
use_ok( 'RDF::Base::Pattern::Union' );

{
	dies_ok { RDF::Base::Pattern->new( pattern => [] ) } 'pattern with no items';
	dies_ok { RDF::Base::Pattern->new( pattern => [ 1 ] ) } 'pattern with non-statement scalar';
	dies_ok { RDF::Base::Pattern->new( pattern => [ bless({}, 'foo') ] ) } 'pattern with non-statement object';
	
	my $subj		= RDF::Query::Node::Resource->new( uri => "foo:bar" );
	my $pred		= RDF::Query::Node::Resource->new( uri => URI->new("http://xmlns.com/foaf/0.1/name") );
	my $obj			= RDF::Query::Node::Literal->new( value => "greg" );
	my $statement	= RDF::Base::Statement->new( subject => $subj, predicate => $pred, object => $obj );
	
	{
		my $pattern		= RDF::Base::Pattern::Triples->new( pattern => [ $statement ] );
		isa_ok( $pattern, 'RDF::Base::Pattern' );
		
		dies_ok { RDF::Base::Pattern::Triples->new( pattern => [ $pattern ] ) } 'triples pattern with non-triple item';
	}
	
	{
		dies_ok { RDF::Base::Pattern::Graph->new( pattern => [ $statement ] ) } 'graph pattern without graph';
		my $uri			= RDF::Query::Node::Resource->new( uri => "http://example.com/" );
		my $pattern		= RDF::Base::Pattern::Graph->new( graph => $uri, pattern => [ $statement ] );
		isa_ok( $pattern, 'RDF::Base::Pattern::Graph' );
	}
	
	{
		my $pattern		= RDF::Base::Pattern::Optional->new( pattern => [ $statement ] );
		isa_ok( $pattern, 'RDF::Base::Pattern::Optional' );
	}
	
	{
		dies_ok { RDF::Base::Pattern::Union->new( pattern => [ $statement ] ) } 'union pattern without RHS';
		my $pattern		= RDF::Base::Pattern::Union->new( pattern => [ $statement ], pattern_b => [ $statement ] );
		isa_ok( $pattern, 'RDF::Base::Pattern' );
	}
	
	{
		my $var			= RDF::Query::Node::Variable->new( name => 'foo' );
		dies_ok { RDF::Base::Pattern::Filter->new( pattern => [ $var ] ) } 'filter pattern without operator';
		my $pattern		= RDF::Base::Pattern::Filter->new( operator => 'BOUND', pattern => [ $var ] );
		isa_ok( $pattern, 'RDF::Base::Pattern' );
	}
	
}
