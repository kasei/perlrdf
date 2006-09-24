#!/usr/bin/perl

use utf8;
use strict;
use warnings;

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use RDF::Base::Storage;
use RDF::Base::Statement;
use_ok( 'RDF::Base::Model' );

{
	my $storage	= RDF::Base::Storage::Memory->new();
	isa_ok( $storage, 'RDF::Base::Storage' );
	my $model	= RDF::Base::Model->new( storage => $storage );
	isa_ok( $model, 'RDF::Base::Model' );
	is( $model->size, 0, 'size' );
	
	my $st	= RDF::Base::Statement->parse('{(greg), [http://xmlns.com/foaf/0.1/name], "greg"}');
	$model->add_statement( $st );
	is( $model->size, 1, 'size' );
	
	$model->add_statement(
		RDF::Base::Statement->parse('{(greg), [http://xmlns.com/foaf/0.1/nick], "kasei"}')	
	);
	is( $model->size, 2, 'size' );
	
	{
		my $stream	= $model->as_stream;
		isa_ok( $stream, 'RDF::Base::Iterator::Statement' );
		
		my $count	= 0;
		while (my $st = $stream->next) {
			$count++;
			ok( $st->subject->equal( RDF::Base::Node->parse('(greg)') ), 'subject: ' . $st->subject->name );
			like( $st->predicate->uri_value, qr#^http://xmlns.com/foaf/0.1/(name|nick)$#, 'predicate: ' . $st->predicate->uri_value );
			like( $st->object->literal_value, qr/^(greg|kasei)$/, "object: " . $st->object->literal_value );
		}
		is( $count, 2, 'as_stream iterator count' );
	}
	
	ok( $model->exists_statement(RDF::Base::Statement->parse(<<"END")), 'contains statement' );
{(greg), [http://xmlns.com/foaf/0.1/nick], "kasei"}
END
	ok( not($model->exists_statement(RDF::Base::Statement->parse(<<"END"))), 'does not contain statement' );
{(greg), [http://xmlns.com/foaf/0.1/name], "gregory"}
END
	
	$model->add_statement(
		RDF::Base::Statement->parse('{(r1), [http://xmlns.com/foaf/0.1/nick], "火星"}')
	);
	
	{
		my $nick	= RDF::Base::Node::Resource->new( uri => 'http://xmlns.com/foaf/0.1/nick' );
		my $stream	= $model->get_statements( undef, $nick, undef );
		my $count	= 0;
		while (my $st = $stream->next) {
			$count++;
			isa_ok( $st->subject, 'RDF::Base::Node::Blank', 'subject: ' . $st->subject->name );
			is( $st->predicate->uri_value, 'http://xmlns.com/foaf/0.1/nick', 'predicate' );
			like( $st->object->literal_value, qr/^(kasei|火星)$/, "object" );
		}
		is( $count, 2, 'get_statements iterator count' );
	}
	
	$model->remove_statement( $st );
	is( $model->size, 2, 'size (after remove_statement)' );
}

