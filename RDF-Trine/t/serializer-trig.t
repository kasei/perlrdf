use Test::More tests => 31;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use_ok('RDF::Trine::Serializer::TriG');


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
		qq[{\n\t<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"\@en .\n}\n],
		'serialize_model_to_string 1'
	],
	[
		{
			'_:b' => {
				'http://example.com/ns#description' => ['quux'],
			},
		},
		qq{{\n\t[] <http://example.com/ns#description> "quux" .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#title> "bar"^^<http://www.w3.org/2001/XMLSchema#string>, "foo" .\n}\n},
		'datatype literal'
	],
	[
		{
			'_:b' => {
				'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
			},
		},
		qq{{\n\t[] <http://example.com/ns#description> [] .\n}\n},
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
		qq{{\n\t<http://example.com/alice> <http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters> "en" ;\n\t\ta <http://xmlns.com/foaf/0.1/Person> ;\n\t\t<http://xmlns.com/foaf/0.1/name> "Alice" .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#description> _:a .\n\t[] <http://example.com/ns#description> _:a .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#description> [\n\t\t\t<http://example.com/ns#bar> "bar" ;\n\t\t\t<http://example.com/ns#foo> "foo"\n\t\t] .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#description> [\n\t\t\t<http://example.com/ns#foo> "FOO", "foo" ;\n\t\t\t<http://example.com/ns#bar> "bar"\n\t\t] .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#description> [\n\t\t\t<http://example.com/ns#foo> "foo"\n\t\t], [\n\t\t\t<http://example.com/ns#bar> "bar"\n\t\t] .\n}\n},
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
		qq{{\n\t[] <http://example.com/ns#description> [\n\t\t\t<http://example.com/ns#foo> [\n\t\t\t\t<http://example.com/ns#bar> "bar"\n\t\t\t]\n\t\t] .\n}\n},
		'multi-level blank objects'
	],
	[
		{
			'_:abc'	=> { 'http://example.com/predicate' => [{type => 'blank', value => '_:head'}] },
			'_:head'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'blank', value => '_:middle'}],
					},
			'_:middle'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{{\n\t[] <http://example.com/predicate> (1 2) .\n}\n},
		'concise rdf:List syntax 1'
	],
	[
		{
			'_:a'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'blank', value => '_:b'}],
					},
			'_:doc'	=> { 'http://example.com/predicate' => [{type => 'blank', value => '_:a'}] },
			'_:b'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{{\n\t[] <http://example.com/predicate> (1 2) .\n}\n},
		'concise rdf:List syntax 2'
	],
	[
		{
			'_:abc'	=> { 'http://example.com/predicate' => [{type => 'blank', value => '_:head'}] },
			'_:head'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}, {type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'blank', value => '_:middle'}],
					},
			'_:middle'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '3', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{{\n\t[] <http://example.com/predicate> [\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 2, 1 ;\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> [\n\t\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 3 ;\n\t\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>\n\t\t\t]\n\t\t] .\n}\n},
		'full rdf:List syntax on invalid list'
	],
	[
		{
			'_:abc'	=> { 'http://example.com/predicate' => [{type => 'blank', value => '_:head'}] },
			'_:head'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://example.com/listElement'}],
					},
			'http://example.com/listElement'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{{\n\t[] <http://example.com/predicate> [\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 1 ;\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://example.com/listElement>\n\t\t] .\n\t<http://example.com/listElement> <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 2 ;\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .\n}\n},
		'full rdf:List syntax on IRI list element'
	],
	[
		{
			'_:b'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'blank', value => '_:a'}],
					},
			'_:a'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{(1 2) .\n},
		'TODO bare concise rdf:List syntax'
	],
	[
		{
			'_:b'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '1', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'blank', value => '_:a'}],
						'http://example.com/predicate' => ['foo'],
					},
			'_:a'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'literal', value => '2', datatype => 'http://www.w3.org/2001/XMLSchema#integer'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
					},
		},
		qq{(1 2) <http://example.com/predicate> "foo" .\n},
		'TODO rdf:List as subject syntax'
	],
	[
		{
			'_:b'	=> {
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' => [{type => 'blank', value => '_:b'}],
						'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' => [{type => 'uri', value => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'}],
						'http://example.com/predicate' => ['foo'],
					},
		},
		qq{{\n\t_:b <http://example.com/predicate> "foo" ;\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:b ;\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .\n}\n},
		'recursive rdf:List'
	],
	
	
	### integers
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '123', datatype => 'http://www.w3.org/2001/XMLSchema#integer' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> 123 .\n}\n],
		'xsd:integer'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => 'baz', datatype => 'http://www.w3.org/2001/XMLSchema#integer' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#integer> .\n}\n],
		'xsd:integer with bad lexical value'
	],
	### doubles
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '-0.5E+6', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> -0.5E+6 .\n}\n],
		'xsd:double'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '1e1', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> 1e1 .\n}\n],
		'xsd:double'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '123', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> "123"^^<http://www.w3.org/2001/XMLSchema#double> .\n}\n],
		'xsd:double with bad lexical value 1'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => 'quux', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> "quux"^^<http://www.w3.org/2001/XMLSchema#double> .\n}\n],
		'xsd:double with bad lexical value 2'
	],
	### decimals
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '-4.0', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> -4.0 .\n}\n],
		'xsd:decimal'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => '+.01', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> +.01 .\n}\n],
		'xsd:decimal'
	],
	[
		{
			'http://example.com/foo' => {
				'http://example.com/bar' => [ {'type' => 'literal','value' => 'baz', datatype => 'http://www.w3.org/2001/XMLSchema#decimal' } ],
			},
		},
		qq[{\n\t<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#decimal> .\n}\n],
		'xsd:decimal with bad lexical value'
	],
);

foreach my $d (@tests) {
	my ($hash, $expect, $test)	= @$d;
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref($hash);
	my $serializer = RDF::Trine::Serializer::TriG->new();
	my $turtle = $serializer->serialize_model_to_string($model);
	TODO: {
		if ($test =~ /TODO/) {
			local $TODO	= "Not implemented yet";
			is($turtle, $expect, $test);
		} else {
			my $pass	= is($turtle, $expect, $test);
			die unless $pass;
		}
	}
}

################################################################################

{
	my $serializer = RDF::Trine::Serializer::TriG->new({ foaf => 'http://xmlns.com/foaf/0.1/' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .

{
	[] foaf:name "Alice" .
	[] foaf:name "Eve" .
}
END
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single namespace Qnames');
}

{
	my $serializer = RDF::Trine::Serializer::TriG->new({ foaf => 'http://xmlns.com/foaf/0.1/', rdfs => 'http://www.w3.org/2000/01/rdf-schema#' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'], 'http://www.w3.org/2000/01/rdf-schema#seeAlso' => [{type=>'resource', value => 'http://alice.me/'}] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
\@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

{
	[] rdfs:seeAlso <http://alice.me/> ;
		foaf:name "Alice" .
	[] foaf:name "Eve" .
}
END
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'multiple namespace Qnames');
}

{
	my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
	my $serializer = RDF::Trine::Serializer::TriG->new({ foaf => $foaf });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .

{
	[] foaf:name "Alice" .
	[] foaf:name "Eve" .
}
END
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'RDF::Trine::Namespace Qnames');
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/predicate' => [
				{'type' => 'literal','value' => 'Foo'},
				{'type' => 'uri','value' => 'http://example.com/bar'},
				'baz@en'
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::TriG->new();
	my $expect	= <<'END';
{
	<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"@en .
}
END
	my $iter	= $model->as_stream;
	my $turtle = $serializer->serialize_iterator_to_string($iter);
	is($turtle, $expect, 'serialize_iterator_to_string 1');
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $parser	= RDF::Trine::Parser->new('nquads');
	my $nquads	= <<"END";
	_:a <b> <a> .
	_:a <b> <z> .
	_:a <b> <a> <g1> .
	_:a <b> <y> <g1> .
	<a> <b> _:a <g2> .
	<a> <b> _:x <g2> .
END
	$parser->parse_into_model(undef, $nquads, $model);
	my $serializer = RDF::Trine::Serializer::TriG->new();
	my $expect	= <<'END';
{
	<http://example.com/doc> <http://example.com/predicate> <http://example.com/bar>, "Foo", "baz"@en .
}
END
	my $iter	= $model->as_stream;
	my $turtle = $serializer->serialize_iterator_to_string($iter);
	is($turtle, $expect, 'serialize_iterator_to_string 1');
}

