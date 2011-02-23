use Test::More tests => 204;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

use FindBin '$Bin';
use lib "$Bin/lib";


use App::Store qw(all_store_tests);

my $data = App::Store::create_data;
my $store	= RDF::Trine::Store::DBI->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::DBI' );
App::Store::all_store_tests($store, $data);

