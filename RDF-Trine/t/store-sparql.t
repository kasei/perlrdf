use FindBin '$Bin';
use lib "$Bin/lib";

use strict;
use warnings;
no warnings 'redefine';

use Test::More;
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

BEGIN {
	my @env = qw(SPARQL_ENDPOINT);
	if ((grep { defined $ENV{"RDFTRINE_STORE_$_"} } @env) == @env) {
		plan tests => 3 + Test::RDF::Trine::Store::number_of_tests;
	}
	else {
		plan skip_all => <<'EOS';
Set the SPARQL environment variables to run these tests
(at least RDFTRINE_STORE_SPARQL_ENDPOINT)
EOS
	}
}

use RDF::Trine qw(iri variable store literal);

use_ok('RDF::Trine::Store::SPARQL');

my $data  = Test::RDF::Trine::Store::create_data;
my $store = RDF::Trine::Store::SPARQL->new(
	$ENV{RDFTRINE_STORE_SPARQL_ENDPOINT},
	$ENV{RDFTRINE_STORE_SPARQL_USER},
	$ENV{RDFTRINE_STORE_SPARQL_PASSWORD},
	{
		realm   => $ENV{RDFTRINE_STORE_SPARQL_REALM},
		#context => $ENV{RDFTRINE_STORE_SPARQL_CONTEXT},
		product => 'virtuoso',
		legacy  => 1,
	}
);

isa_ok($store, 'RDF::Trine::Store::SPARQL');
can_ok($store, '_new_with_config');

#Test::RDF::Trine::Store::add_quads($store, undef, @{$data->{quads}});
#diag($_) for $store->_objects;

#qTest::RDF::Trine::Store::all_store_tests(
#	$store, $data, undef, { update_sleep => 0 });

my $iter = $store->get_sparql(<<'EOQ');
construct { ?s ?p ?o } where { ?s ?p ?o filter isBLANK(?s) }
EOQ
# prefix x: <urn:uuid:4095619e-dcea-4eec-8b81-6a5a7106c29f>
# construct { x: ?b ?c . ?c ?d ?e . ?f ?g ?h }
# where {
#  { x: ?b ?c }
#  optional { ?c ?d ?e }
#  optional { ?f ?g ?h; ?i x: }
# }
# EOQ

warn $iter;
