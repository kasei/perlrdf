use Test::More;

use FindBin '$Bin';
use lib "$Bin/lib";

use RDF::Trine::Store::Dydra;
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

my $user	= $ENV{DYDRA_USER};
my $repo	= $ENV{DYDRA_REPO};
my $token	= $ENV{DYDRA_TOKEN};

if (not($ENV{RDFTRINE_NETWORK_TESTS})) {
  plan skip_all => "No network. Set RDFTRINE_NETWORK_TESTS to run these tests.";
} elsif (defined($user) and defined($repo) and defined($token)) {
  plan tests => 3 + Test::RDF::Trine::Store::number_of_tests;
} else {
  plan skip_all => 'Dydra ENV variables were not found';
}

use strict;
use warnings;
no warnings 'redefine';


my $data = Test::RDF::Trine::Store::create_data;
my $store	= RDF::Trine::Store::Dydra->new($user, $repo, $token);
isa_ok( $store, 'RDF::Trine::Store::Dydra' );

my %args;
$args{ update_sleep }	= 5;
Test::RDF::Trine::Store::all_store_tests($store, $data, 0, \%args);

done_testing;
