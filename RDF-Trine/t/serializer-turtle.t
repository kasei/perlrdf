use Test::More tests => 24;
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
	my $expect	= qq[<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"\@en .\n];
	my $iter	= $model->as_stream;
	my $turtle = $serializer->serialize_iterator_to_string($iter);
	is($turtle, $expect, 'serialize_iterator_to_string 1');
}

################################################################################

my @tests	= (
	[
		{
			'http://example.com/doc'	=> {
				'http://example.com/predicate' => [
					{'type' => 'literal','value' => 'Foo'},
					{'type' => 'uri','value' => 'http://example.com/bar'},
					'baz@en'
				],
			}
		},
		qq[<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"\@en .\n],
		'serialize_model_to_string 1'
	],
	[
		{
			'_:b' => {
				'http://example.com/ns#description' => ['quux'],
			},
		},
		qq{[] <http://example.com/ns#description> "quux" .\n},
		'simple literal'
	],
	[
		{
			'_:a' => {
				'http://example.com/ns#title' => [
					'foo',
					{type => 'literal', value => 'bar', datatype => 'http://www.w3.org/2001/XMLSchema#string'},
				],
			},
		},
		qq{[] <http://example.com/ns#title> "bar"^^<http://www.w3.org/2001/XMLSchema#string>, "foo" .\n},
		'datatype literal'
	],
	[
		{
			'_:b' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
			},
		},
		qq{[] <http://example.com/ns#description> [] .\n},
		'blank object'
	],
	[
		{
			'http://example.com/alice' => {
				'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' => [{ type => 'resource', value => 'http://xmlns.com/foaf/0.1/Person' }],
				'http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters' => ['en'],
				'http://xmlns.com/foaf/0.1/name' => [ 'Alice', {'type' => 'literal','value' => 'Alice', language => 'en' } ],
			},
		},
		qq{<http://example.com/alice> <http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters> "en" ;\n\ta <http://xmlns.com/foaf/0.1/Person> ;\n\t<http://xmlns.com/foaf/0.1/name> "Alice" .\n},
		'multiple namespaces'
	],
	[
		{
			'_:b' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
			},
			'_:c' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
			},
		},
		qq{[] <http://example.com/ns#description> _:a .\n[] <http://example.com/ns#description> _:a .\n},
		'shared blank object'
	],
	[
		{
			'_:a' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:b'}],
			},
			'_:b' => {
				'http://example.com/ns#foo' => [{type=>'literal', value=>'foo'}],
				'http://example.com/ns#bar' => [{type=>'literal', value=>'bar'}],
			},
		},
		qq{[] <http://example.com/ns#description> [\n\t\t<http://example.com/ns#bar> "bar" ;\n\t\t<http://example.com/ns#foo> "foo"\n\t] .\n},
		'blank object with multiple predicates'
	],
	[
		{
			'_:a' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:b'}],
			},
			'_:b' => {
				'http://example.com/ns#foo' => [{type=>'literal', value=>'foo'}, 'FOO'],
				'http://example.com/ns#bar' => [{type=>'literal', value=>'bar'}],
			},
		},
		qq{[] <http://example.com/ns#description> [\n\t\t<http://example.com/ns#bar> "bar" ;\n\t\t<http://example.com/ns#foo> "FOO", "foo"\n\t] .\n},
		'blank object with multiple predicates and objects'
	],
	[
		{
			'_:a' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:b'}, {type=>'uri', value=>'_:c'}],
			},
			'_:b' => {
				'http://example.com/ns#foo' => [{type=>'literal', value=>'foo'}],
			},
			'_:c' => {
				'http://example.com/ns#bar' => ['bar'],
			},
		},
		qq{[] <http://example.com/ns#description> [\n\t\t<http://example.com/ns#foo> "foo"\n\t], [\n\t\t<http://example.com/ns#bar> "bar"\n\t] .\n},
		'multiple blank objects'
	],
	[
		{
			'_:a' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:b'}],
			},
			'_:b' => {
				'http://example.com/ns#foo' => [{type=>'uri', value=>'_:c'}],
			},
			'_:c' => {
				'http://example.com/ns#bar' => ['bar'],
			},
		},
		qq{[] <http://example.com/ns#description> [\n\t\t<http://example.com/ns#foo> [\n\t\t\t<http://example.com/ns#bar> "bar"\n\t\t]\n\t] .\n},
		'multi-level blank objects'
	],
	
	
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

{
	foreach my $d (@tests) {
		my ($hash, $expect, $test)	= @$d;
		my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
		$model->add_hashref($hash);
		my $serializer = RDF::Trine::Serializer::Turtle->new();
		my $turtle = $serializer->serialize_model_to_string($model);
		is($turtle, $expect, $test);
	}
}

################################################################################

{
	my $serializer = RDF::Trine::Serializer::Turtle->new({ foaf => 'http://xmlns.com/foaf/0.1/' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .

[] foaf:name "Alice" .
[] foaf:name "Eve" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single namespace Qnames');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new({ foaf => 'http://xmlns.com/foaf/0.1/', rdfs => 'http://www.w3.org/2000/01/rdf-schema#' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'], 'http://www.w3.org/2000/01/rdf-schema#seeAlso' => [{type=>'resource', value => 'http://alice.me/'}] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
\@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

[] rdfs:seeAlso <http://alice.me/> ;
	foaf:name "Alice" .
[] foaf:name "Eve" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'multiple namespace Qnames');
}

{
	my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
	my $serializer = RDF::Trine::Serializer::Turtle->new({ foaf => $foaf });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .

[] foaf:name "Alice" .
[] foaf:name "Eve" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'RDF::Trine::Namespace Qnames');
}
