use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use RDF::Trine::Store::Redis;
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

plan tests => 1 + Test::RDF::Trine::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

my $data = Test::RDF::Trine::Store::create_data;
my $store	= RDF::Trine::Store::Redis->new();
isa_ok( $store, 'RDF::Trine::Store::Redis' );

$store->nuke;
Test::RDF::Trine::Store::all_store_tests($store, $data, 0);
$store->nuke;

done_testing;
