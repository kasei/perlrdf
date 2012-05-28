use Test::More tests => 3;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use_ok('RDF::Trine::Serializer::RDFJSON');

my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);

$model->add_hashref({
	'http://example.com/doc' => {
		'http://example.com/predicate' => [
				{
					'type' => 'literal',
					'value' => 'Foo',
				},
				{
					'type' => 'uri',
					'value' => 'http://example.com/bar',
				},
				'baz@en'
			],
		},
	});

ok($model->count_statements(
		RDF::Trine::Node::Resource->new('http://example.com/doc'),
		RDF::Trine::Node::Resource->new('http://example.com/predicate'),
		RDF::Trine::Node::Literal->new('baz', 'en'),
		),
	"add_hashref works");

my $serializer = RDF::Trine::Serializer::RDFJSON->new();	
my $json = $serializer->serialize_model_to_string($model);

ok($json =~ /^\{/, "RDF/JSON serialiser seems to work");

