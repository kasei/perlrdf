use Test::More tests => 5;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use_ok('RDF::Trine::Serializer::RDFJSON');

my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);

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

my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
my $new_model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
$parser->parse_into_model(undef, $json, $new_model);

ok($model->count_statements(
		RDF::Trine::Node::Resource->new('http://example.com/doc'),
		RDF::Trine::Node::Resource->new('http://example.com/predicate'),
		RDF::Trine::Node::Resource->new('http://example.com/bar'),
		),
	"RDF/JSON parser works");

my $data = $new_model->as_hashref;

ok(defined $data->{'http://example.com/doc'}->{'http://example.com/predicate'}->[2]->{'value'},
	"as_hashref seems to work");
