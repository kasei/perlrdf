use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use Module::Load::Conditional qw[can_load];

BEGIN {
	can_load(modules => {'RDF::Redland' => 1.000701}) || plan skip_all => 'Test needs RDF::Redland';
}

diag("Testing with RDF::Redland $RDF::Redland::VERSION");

use RDF::Redland;
use RDF::Trine::Store::Redland;

use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

unless ($RDF::Trine::Store::HAVE_REDLAND) {
  plan skip_all => 'Redland was not found';
}

use strict;
use warnings;
no warnings 'redefine';

my $data = Test::RDF::Trine::Store::create_data;
my $store	= RDF::Trine::Store::Redland->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::Redland' );

Test::RDF::Trine::Store::all_triple_store_tests($store, $data);

done_testing;
