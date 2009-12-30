use Test::More tests => 16;
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
	a <http://xmlns.com/foaf/0.1/Person> ;
	<http://xmlns.com/foaf/0.1/name> "Alice" .
END
	
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'serialize_model_to_string 5: multiple namespaces');
}

# numeric type tests
{
	my @tests	= (
		### integers
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '123', datatype => 'http://www.w3.org/2001/XMLSchema#integer' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> 123 .\n],
			'xsd:integer'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => 'baz', datatype => 'http://www.w3.org/2001/XMLSchema#integer' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#integer> .\n],
			'xsd:integer with bad lexical value'
		],
		### doubles
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '-0.5E+6', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> -0.5E+6 .\n],
			'xsd:double'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '1e1', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> 1e1 .\n],
			'xsd:double'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '123', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> "123"^^<http://www.w3.org/2001/XMLSchema#double> .\n],
			'xsd:double with bad lexical value 1'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => 'quux', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> "quux"^^<http://www.w3.org/2001/XMLSchema#double> .\n],
			'xsd:double with bad lexical value 2'
		],
		### decimals
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '-4.0', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> -4.0 .\n],
			'xsd:decimal'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => '+.01', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> +.01 .\n],
			'xsd:decimal'
		],
		[
			{
				'http://example.com/foo' => {
					'http://example.com/bar' => [ {'type' => 'literal','value' => 'baz', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
				},
			},
			qq[<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#decimal> .\n],
			'xsd:decimal with bad lexical value'
		],
	);
	
	
	foreach my $d (@tests) {
		my ($hash, $expect, $test)	= @$d;
		my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
		$model->add_hashref($hash);
		my $serializer = RDF::Trine::Serializer::Turtle->new();
		my $turtle = $serializer->serialize_model_to_string($model);
		is($turtle, $expect, $test);
	}
}


