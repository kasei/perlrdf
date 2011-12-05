use strict;
use warnings;
no warnings 'redefine';

use Test::More;
use FindBin '$Bin';
use lib "$Bin/lib";
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

my $tests	= 1 + Test::RDF::Trine::Store::number_of_tests;

SKIP: {
	eval "use RDF::Trine::Store::Redis;";
	if ($@) {
		plan skip_all => "Need Redis to run these tests.";
	} elsif (not exists $ENV{RDFTRINE_STORE_REDIS_SERVER}) {
		plan skip_all => "Set the Redis environment variable to run these tests (RDFTRINE_STORE_REDIS_SERVER)";
	} else {
		plan tests => $tests;
	}
	my $server	= $ENV{RDFTRINE_STORE_REDIS_SERVER};
	
	
	
	my $data = Test::RDF::Trine::Store::create_data;
	my $store	= RDF::Trine::Store::Redis->new( server => $server );
	isa_ok( $store, 'RDF::Trine::Store::Redis' );
	
	$store->nuke;
	Test::RDF::Trine::Store::all_store_tests($store, $data, 0);
	$store->nuke;
}

done_testing;
