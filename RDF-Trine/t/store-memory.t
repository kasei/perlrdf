use Test::More tests => 171;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

use FindBin '$Bin';
use lib "$Bin/lib";


use App::Store qw(all_store_tests);

my $data = App::Store::create_data;
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
  App::Store::all_store_tests($store, $data);
}
