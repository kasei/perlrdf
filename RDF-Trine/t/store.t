use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace;

use FindBin '$Bin';
use lib "$Bin/lib";


use App::Store qw(all_store_tests);

my @stores	= test_stores();
plan tests => 5 + scalar(@stores) * 167;

{
	isa_ok( store( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'SPARQL;http://example/' ), 'RDF::Trine::Store::SPARQL' );
}

foreach (@stores) {
  App::Store::all_store_tests($_);
}

#{
#	my $store	= RDF::Trine::Store::Memory->new();
#	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d) );
#	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->r, $ex->t, $ex->u, $ex->v) );
#	is( $store->_statement_id($ex->a, $ex->t, $ex->c, $ex->d), -1, '_statement_id' );
#	is( $store->_statement_id($ex->w, $ex->x, $ex->z, $ex->z), -1, '_statement_id' );
#}


sub test_stores {
	my @stores;
	push(@stores, RDF::Trine::Store::DBI->temporary_store());
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	if ($RDF::Trine::Store::HAVE_REDLAND) {
		push(@stores, RDF::Trine::Store::Redland->temporary_store());
	}
	return @stores;
}
