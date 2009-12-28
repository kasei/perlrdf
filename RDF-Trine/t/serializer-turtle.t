use Test::More tests => 7;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use_ok('RDF::Trine::Serializer::Turtle');


{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/predicate' => [
				{'type' => 'literal','value' => 'Foo'},
				{'type' => 'uri','value' => 'http://example.com/bar'},
				'baz@en'
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $expect	= <<'END';
<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"@en .
END
	
	{
		my $turtle = $serializer->serialize_model_to_string($model);
		is($turtle, $expect, 'serialize_model_to_string 1');
	}
	{
		my $iter	= $model->as_stream;
		my $turtle = $serializer->serialize_iterator_to_string($iter);
		is($turtle, $expect, 'serialize_iterator_to_string 1');
	}
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref({
		'_:b' => {
			'http://example.com/ns#description' => ['quux'],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $turtle = $serializer->serialize_model_to_string($model);
	
	is($turtle, <<"END", 'serialize_model_to_string 2: simple literal');
_:b <http://example.com/ns#description> "quux" .
END
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref({
		'_:a' => {
			'http://example.com/ns#title' => [
				'foo',
				{type => 'literal', value => 'bar', datatype => 'http://www.w3.org/2001/XMLSchema#string'},
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $turtle = $serializer->serialize_model_to_string($model);
	
	is($turtle, <<"END", 'serialize_model_to_string 3: datatype literal');
_:a <http://example.com/ns#title> "bar"^^<http://www.w3.org/2001/XMLSchema#string>, "foo" .
END
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref({
		'_:b' => {
			'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $turtle = $serializer->serialize_model_to_string($model);
	
	is($turtle, <<"END", 'serialize_model_to_string 4: blank object');
_:b <http://example.com/ns#description> _:a .
END
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref({
		'http://example.com/alice' => {
			'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' => [{ type => 'resource', value => 'http://xmlns.com/foaf/0.1/Person' }],
			'http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters' => ['en'],
			'http://xmlns.com/foaf/0.1/name' => [ 'Alice', {'type' => 'literal','value' => 'Alice', language => 'en' } ],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $expect	= <<"END";
<http://example.com/alice> <http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters> "en" ;
	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> ;
	<http://xmlns.com/foaf/0.1/name> "Alice" .
END
	
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'serialize_model_to_string 5: multiple namespaces');
}
