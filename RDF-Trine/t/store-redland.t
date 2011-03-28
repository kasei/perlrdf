use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use Module::Load::Conditional qw[can_load];

BEGIN {
  can_load(modules => {'RDF::Redland' => 0});
}

use RDF::Redland;

use App::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

if ($RDF::Trine::Store::HAVE_REDLAND) {
  plan tests => 1 + App::Store::number_of_tests;
} else {
  plan skip_all => 'Redland was not found';
}


use strict;
use warnings;
no warnings 'redefine';



my $data = App::Store::create_data;
my $store	= RDF::Trine::Store::Redland->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::Redland' );
App::Store::all_store_tests($store, $data);

