use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use Module::Load::Conditional qw[can_load];

BEGIN {
 can_load(modules => {'RDF::Redland' => 1.000701}) || plan skip_all => 'Test needs RDF::Redland';
}

use RDF::Redland;

use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

if ($RDF::Trine::Store::HAVE_REDLAND) {
  plan tests => 3 + Test::RDF::Trine::Store::number_of_tests;
} else {
  plan skip_all => 'Redland was not found';
}


use strict;
use warnings;
no warnings 'redefine';



my $data = Test::RDF::Trine::Store::create_data;
my $store	= RDF::Trine::Store::Redland->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::Redland' );

Test::RDF::Trine::Store::all_store_tests($store, $data, 1);

done_testing;
