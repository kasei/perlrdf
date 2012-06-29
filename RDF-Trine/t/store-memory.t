use FindBin '$Bin';
use lib "$Bin/lib";

use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use Test::More tests => 7 + Test::RDF::Trine::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;
use RDF::Trine::Namespace qw(rdf rdfs);
use RDF::Trine qw[iri literal blank variable statement];
use RDF::Trine::Model;

my $data = Test::RDF::Trine::Store::create_data;
my $ex = $data->{ex};

{
	my $store	= RDF::Trine::Store::Memory->new();
	isa_ok( $store, 'RDF::Trine::Store::Memory' );
	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d) );
	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->r, $ex->t, $ex->u, $ex->v) );
	is( $store->_statement_id($ex->a, $ex->t, $ex->c, $ex->d), -1, '_statement_id' );
	is( $store->_statement_id($ex->w, $ex->x, $ex->z, $ex->z), -1, '_statement_id' );
}

{
  my $store	= RDF::Trine::Store::Memory->temporary_store();
  isa_ok( $store, 'RDF::Trine::Store::Memory' );
  Test::RDF::Trine::Store::all_store_tests($store, $data);
}


{
	my $parser	= RDF::Trine::Parser->new( 'turtle' );
	my $store	= RDF::Trine::Store::Memory->new();
	my $model = RDF::Trine::Model->new( $store );
	
	my $ttl			= <<'END';
@base <http://localhost/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

</foo> rdfs:label "This is a test"@en ;
  <http://xmlns.com/foaf/0.1/page> <http://en.wikipedia.org/wiki/Foo> .
</bar/baz/bing> rdfs:label "Testing with longer URI."@en .

END
	$parser->parse_into_model( 'http://localhost', $ttl, $model );
	my $etag1	= $model->etag;
	$model->add_statement(statement(iri('http://localhost/foo'), $rdfs->label, literal('DAAAAHUT')));
	my $etag2	= $model->etag;
	isnt( $etag1, $etag2, 'changed etag' );
	$model->add_statement(statement(iri('http://localhost/foo'), $rdfs->label, literal('DAHUT')));
	my $etag3	= $model->etag;
	isnt( $etag3, $etag1, 'changed etag' );
	isnt( $etag3, $etag2, 'changed etag' );
}
