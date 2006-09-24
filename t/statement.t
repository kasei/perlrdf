#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use_ok( 'RDF::Base::Statement' );

{
	my $subj		= RDF::Base::Node::Resource->new( uri => "foo:bar" );
	my $pred		= RDF::Base::Node::Resource->new( uri => URI->new("http://xmlns.com/foaf/0.1/name") );
	my $obj			= RDF::Base::Node::Literal->new( value => "greg" );
	my $blank		= RDF::Base::Node::Blank->new( name => time() );
		
	my $statement	= RDF::Base::Statement->new( subject => $subj, predicate => $pred, object => $obj );
	my $st2			= RDF::Base::Statement->new( subject => $subj, predicate => RDF::Base::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' ), object => $obj );
	my $st3			= RDF::Base::Statement->new( subject => $subj, predicate => $pred, object => $blank );
	my $st4			= RDF::Base::Statement->parse('{[foo:bar], [http://xmlns.com/foaf/0.1/name], "greg"}');
	my $st5			= RDF::Base::Statement->parse('{[foo:quux], [http://xmlns.com/foaf/0.1/name], "greg"}');
	my $st6			= RDF::Base::Statement->parse('{[foo:quux], [http://xmlns.com/foaf/0.1/nick], "greg"}');
	my $st7			= RDF::Base::Statement->new(
						subject		=> RDF::Base::Node::Resource->new( uri => 'foo:quux' ),
						predicate	=> RDF::Base::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/name' ),
						object		=> RDF::Base::Node::Literal->new( value => "greg" ),
						context		=> RDF::Base::Node::Resource->new( uri => 'http://example.com/' ),
					);
	my $st8			= RDF::Base::Statement->parse(q({[foo:quux], [http://xmlns.com/foaf/0.1/name], 'greg'} [http://example.com/]));
	
	for ($statement, $st2, $st3, $st4) {
		isa_ok( $_, 'RDF::Base::Statement' );
	}
	
	isa_ok( $statement, 'RDF::Base::Statement' );
	is( $statement->has_context, 0, 'has_context' );
	ok( $statement->equal( $st2 ), 'statement equality' );
	ok( $statement->equal( $st4 ), 'statement equality' );
	ok( not($st4->equal( $st5 )), 'statement equality (subject)' );
	ok( not($st5->equal( $st6 )), 'statement equality (predicate)' );
	ok( not($statement->equal( $st3 )), 'statement equality (object)' );
	ok( not($st5->equal( $st7 )), 'statement equality (context)' );
	ok( not($st7->equal( $st5 )), 'statement equality (context)' );
	ok( $st7->equal( $st8 ), 'statement equality (context)' );
	
	ok( not($statement->equal( $subj )), 'statement equality' );
	is( RDF::Base::Statement->parse('{}'), undef, 'empty in statement' );
	is( RDF::Base::Statement->parse('{[foo:quux], die!'), undef, 'unterminated statement' );
	is( RDF::Base::Statement->parse('{[foo:quux], [foo:bleh]}'), undef, 'not enough nodes in statement' );
	is( RDF::Base::Statement->parse('{[foo:quux], bar, baz}'), undef, 'garbage in statement' );
}

