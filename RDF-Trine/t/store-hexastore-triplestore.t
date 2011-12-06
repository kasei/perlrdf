use FindBin '$Bin';
use lib "$Bin/lib";

use Test::RDF::Trine::Store qw(all_triple_store_tests number_of_triple_tests);

use Test::More tests => 1 + Test::RDF::Trine::Store::number_of_triple_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;



my $data = Test::RDF::Trine::Store::create_data;
my $ex = $data->{ex};

my $store	= RDF::Trine::Store::Hexastore->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::Hexastore' );
Test::RDF::Trine::Store::all_triple_store_tests($store, $data);

done_testing;
