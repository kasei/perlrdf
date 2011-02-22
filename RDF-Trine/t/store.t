use Test::More;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

use FindBin '$Bin';
use lib "$Bin/lib";


use App::Store qw(all_store_tests);

my @stores	= test_stores();
plan tests => 3 + scalar(@stores) * 167;

{
	isa_ok( store( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'SPARQL;http://example/' ), 'RDF::Trine::Store::SPARQL' );
}

my $data = App::Store::create_data;


foreach (@stores) {
  App::Store::all_store_tests($_, $data);
}

sub test_stores {
	my @stores;
	push(@stores, RDF::Trine::Store::DBI->temporary_store());
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	if ($RDF::Trine::Store::HAVE_REDLAND) {
		push(@stores, RDF::Trine::Store::Redland->temporary_store());
	}
	return @stores;
}
