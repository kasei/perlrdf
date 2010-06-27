use Test::More;
use Test::Exception;

use strict;
use warnings;

use RDF::Trine;
use RDF::Trine::Store;
use FindBin qw($Bin);
use File::Spec;

my $path	= File::Spec->catfile( $Bin, 'data' );

TODO: {
  local $TODO = "Implementing Config by hashref";

  {
    my $store = RDF::Trine::Store->new_with_config(store => 'Memory',
						   sources => [
							       {
								file => File::Spec->catfile($path, 'turtle', 'test-23.ttl'),
								syntax => 'turtle',
							       }
							      ]);
    isa_ok($store, 'RDF::Trine::Store::Memory');
    is($store->size, 1, "One statement in the model");
    my $it = $store->get_statements(RDF::Trine::Node::Resource->new('http://example.org/ex#a'), RDF::Trine::Node::Resource->new('http://example.org/ex#b'), undef); 
    like($it->to_string, qr/Hello World/, 'Contains Hello World string');
  }

  {
    my $store = RDF::Trine::Store->new_with_config(store => 'Hexastore',
						   sources => [
							       {
								file => File::Spec->catfile($path, 'turtle', 'test-23.ttl'),
								syntax => 'turtle',
							       },
							       {
								file => File::Spec->catfile($path, 'rdfxml-w3c', 'rdfms-xml-literal-namespaces', 'test001.rdf'),
								syntax => 'rdfxml',
							       }
							      ]);
    isa_ok($store, 'RDF::Trine::Store::Hexastore');
    is($store->size, 2, "Two statements in the model");
    my $it = $store->get_statements(RDF::Trine::Node::Resource->new('http://example.org/ex#a'), RDF::Trine::Node::Resource->new('http://example.org/ex#b'), undef); 
    like($it->to_string, qr/Hello World/, 'Contains Hello World string');
  }

  {
    my $store = RDF::Trine::Store->new_with_config(store => 'Memory',
						   sources => [
							       {
								file => File::Spec->catfile($path, 'turtle', 'test-23.ttl'),
								syntax => 'turtle',
								graph => 'http://example.org/local-stuff'
							       },
							       {
								file => File::Spec->catfile($path, 'rdfxml-w3c', 'rdfms-xml-literal-namespaces', 'test001.rdf'),
								syntax => 'rdfxml',
							       }
							      ]);
    isa_ok($store, 'RDF::Trine::Store::Memory');
    is($store->size, 2, "Two statements in the model");
    is($store->count_statements(undef, undef, undef, RDF::Trine::Node::Resource->new('http://example.org/local-stuff')), 1, "Only one statement in the graph");
    my $it = $store->get_statements(RDF::Trine::Node::Resource->new('http://example.org/ex#a'), RDF::Trine::Node::Resource->new('http://example.org/ex#b'), undef);
    like($it->to_string, qr/Hello World/, 'Contains Hello World string');
  }



  SKIP: {
      unless ($ENV{RDFTRINE_NETWORK_TESTS}) {
	skip( "No network. Set RDFTRINE_NETWORK_TESTS to run these tests.", 2 );
      }
    
      my $store = RDF::Trine::Store->new_with_config(store => 'Memory',
						     sources => [
								 {
								  file => File::Spec->catfile($path, 'turtle', 'test-23.ttl'),
								  syntax => 'turtle',
								 },
								 {
								  url => 'http://www.kjetil.kjernsmo.net/foaf',
								  syntax => 'rdfxml',
							         }
								]);
      isa_ok($store, 'RDF::Trine::Store::Memory');
      my $it = $store->get_statements(RDF::Trine::Node::Resource->new('http://www.kjetil.kjernsmo.net/foaf#me'), RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/nick'), undef);
      like($it->to_string, qr/KjetilK/, 'Contains Hello World string');
  }


  throws_ok {
    my $store = RDF::Trine::Store->new_with_config(store => 'Memory',
						   sources => [
							       {
								file => File::Spec->catfile($path, 'turtle', 'bad-00.ttl'),
								syntax => 'turtle',
							       }
							      ]);
  } 'RDF::Trine::Error::ParserError', 'Throws on parsing bad Turtle file';


  throws_ok {
    my $store = RDF::Trine::Store->new_with_config(store => 'FooBar');
  } 'RDF::Trine::Error', 'Throws on parsing non-existent Store.';


}


done_testing();
