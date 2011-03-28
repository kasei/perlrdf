use FindBin '$Bin';
use lib "$Bin/lib";


use App::Store qw(all_store_tests number_of_tests);

use Test::More tests => 1 + App::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;



my $data = App::Store::create_data;
my $store	= RDF::Trine::Store::DBI->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::DBI' );
App::Store::all_store_tests($store, $data);

