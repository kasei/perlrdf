use Test::More tests => 3;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use_ok('RDF::Trine::Parser::RDFJSON');

my $json	=<<"END";
{
	"http://example.com/doc": {
		"http://example.com/predicate":[
			{"value":"http://example.com/bar","type":"uri"},
			{"value":"Foo","type":"literal"},
			{"lang":"en","value":"baz","type":"literal"}
		]
	}
}
END
my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
$parser->parse_into_model(undef, $json, $model);

ok($model->count_statements(
		RDF::Trine::Node::Resource->new('http://example.com/doc'),
		RDF::Trine::Node::Resource->new('http://example.com/predicate'),
		RDF::Trine::Node::Resource->new('http://example.com/bar'),
		),
	"RDF/JSON parser works");

my $data = $model->as_hashref;

ok(defined $data->{'http://example.com/doc'}->{'http://example.com/predicate'}->[2]->{'value'},
	"as_hashref seems to work");
