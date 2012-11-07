use FindBin '$Bin';
use lib "$Bin/lib";


use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use Test::More tests => 2 + Test::RDF::Trine::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);

use_ok('RDF::Trine::Store::DBIC');

my $data = Test::RDF::Trine::Store::create_data;
my $store	= RDF::Trine::Store::DBIC->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::DBIC' );
Test::RDF::Trine::Store::all_store_tests($store, $data);

