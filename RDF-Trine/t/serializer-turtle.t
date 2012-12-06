use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed reftype);
use utf8;

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Namespace qw(rdf foaf);
use_ok('RDF::Trine::Serializer::Turtle');


my $ex		= RDF::Trine::Namespace->new('http://example.com/');
my $ns		= RDF::Trine::Namespace->new('http://example.com/ns#');
my $lang	= RDF::Trine::Namespace->new('http://purl.org/net/inkel/rdf/schemas/lang/1.1#');

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
		[
			statement($ex->alice, $rdf->type, $foaf->Person),
			statement($ex->alice, $foaf->name, literal('Alice', 'en')),
			statement($ex->alice, $lang->masters, literal('en')),
		],
		qr{<http://example.com/alice> a <http://xmlns.com/foaf/0.1/Person> ;\n\t<http://xmlns.com/foaf/0.1/name> "Alice"\@en ;\n\t<http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters> "en" .\n},
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
				'http://example.com/ns#foo' => ['foo'],
				'http://example.com/ns#bar' => ['bar'],
			},
		},
		qq{[] <http://example.com/ns#description> [\n\t\t<http://example.com/ns#bar> "bar" ;\n\t\t<http://example.com/ns#foo> "foo"\n\t] .\n},
		'blank object with multiple predicates'
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
		qq{[] <http://example.com/predicate> (1 2) .\n},
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
		qq{[] <http://example.com/predicate> (1 2) .\n},
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
		qq{[] <http://example.com/predicate> [\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 2, 1 ;\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> [\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 3 ;\n\t\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>\n\t\t]\n\t] .\n},
		'TODO: full rdf:List syntax on invalid list'
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
		qq{[] <http://example.com/predicate> [\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 1 ;\n\t\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://example.com/listElement>\n\t] .\n<http://example.com/listElement> <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> 2 ;\n\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .\n},,
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
		[
			statement(blank('b'), $ex->predicate, literal('foo')),
			statement(blank('b'), $rdf->first, blank('b')),
			statement(blank('b'), $rdf->rest, $rdf->nil),
		],
		qq{_:b <http://example.com/predicate> "foo" ;\n\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#first> _:b ;\n\t<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .\n},
		'recursive rdf:List'
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
				'http://example.com/bar' => [ {'type' => 'literal','value' => 'quux', datatype => 'http://www.w3.org/2001/XMLSchema#double' } ],
			},
		},
		qq[<http://example.com/foo> <http://example.com/bar> "quux"^^<http://www.w3.org/2001/XMLSchema#double> .\n],
		'xsd:double with bad lexical value'
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
	my ($data, @data)	= @$d;
	my $test	= pop(@data);
	my @expects	= @data;
	
	my $turtle;
	my $serializer	= RDF::Trine::Serializer::Turtle->new();
	if (reftype($data) eq 'HASH') {
		my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
		$model->add_hashref($data);
		$turtle	= $serializer->serialize_model_to_string($model);
	} else {
		my $iter	= RDF::Trine::Iterator->new($data);
		$turtle	= $serializer->serialize_iterator_to_string($iter);
	}
	TODO: {
		foreach my $expect (@expects) {
			my $re	= (blessed($expect) and $expect->isa('Regexp'));
			if ($test =~ /TODO/) {
				local $TODO	= "Not implemented yet";
				if ($re) {
					like($turtle, $expect, $test);
				} else {
					is($turtle, $expect, $test);
				}
			} else {
				if ($re) {
					like($turtle, $expect, $test);
				} else {
					is($turtle, $expect, $test);
				}
			}
		}
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single namespace Qnames');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new(base_uri => 'http://example.org/foo');
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/homepage' => [{ 'type'=>'uri', 'value'=>'./bar' }]
	}};
	my $expect	= <<"END";
\@base <http://example.org/foo> .

[] <http://xmlns.com/foaf/0.1/homepage> <./bar> .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single base URI');
}

{
  # Retained for backwards compatibility
	my $serializer = RDF::Trine::Serializer::Turtle->new(base => 'http://example.org/foo');
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/homepage' => [{ 'type'=>'uri', 'value'=>'./bar' }]
	}};
	my $expect	= <<"END";
\@base <http://example.org/foo> .

[] <http://xmlns.com/foaf/0.1/homepage> <./bar> .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single base URI, old style');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new({ foaf => 'http://xmlns.com/foaf/0.1/', foo => 'foo://', bar => 'http://bar/' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .

[] foaf:name "Alice" .
[] foaf:name "Eve" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'single namespace Qnames (ignoring extra namespaces)');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new({ foaf => 'http://xmlns.com/foaf/0.1/', foo => 'foo://', bar => 'http://bar/' });
	my $hash	= {
		'_:a' => { 'http://xmlns.com/foaf/0.1/name' => ['Alice'] },
		'_:b' => { 'http://xmlns.com/foaf/0.1/name' => ['Eve'] },
	};
	my $expect	= <<"END";
\@prefix bar: <http://bar/> .
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
\@prefix foo: <foo://> .

[] foaf:name "Alice" .
[] foaf:name "Eve" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle	= '';
	open( my $fh, '>', \$turtle );
	$serializer->serialize_model_to_file($fh, $model);
	close($fh);
	is($turtle, $expect, 'single namespace Qnames (including extra namespaces)');
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'multiple namespace Qnames (old namespace API)');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => { foaf => 'http://xmlns.com/foaf/0.1/', rdfs => 'http://www.w3.org/2000/01/rdf-schema#' } );
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'multiple namespace Qnames (new namespace API)');
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'RDF::Trine::Namespace Qnames');
}

{
	my $serializer = RDF::Trine::Serializer::Turtle->new({ ex => 'http://example.org/' });
	my $s		= RDF::Trine::Node::Blank->new('a');
	my $p		= RDF::Trine::Node::Resource->new("http://example.org/Ä");
	my $o		= RDF::Trine::Node::Literal->new("Ä");
	my $st		= RDF::Trine::Statement->new($s, $p, $o);
	my $expect	= <<"END";
\@prefix ex: <http://example.org/> .

[] ex:Ä "\\u00C4" .
END
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_statement($st);
	my $turtle = $serializer->serialize_model_to_string($model);
	is($turtle, $expect, 'IRI with prefixes');
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
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
	my $iter	= RDF::Trine::Iterator->new([
		statement($ex->doc, $ex->predicate, $ex->bar),
		statement($ex->doc, $ex->predicate, literal('Foo')),
		statement($ex->doc, $ex->predicate, literal('baz', 'en')),
	]);
	my $turtle = $serializer->serialize_iterator_to_string($iter);
	is($turtle, $expect, 'serialize_iterator_to_string 1');
}

{
	# bug found 2010.02.23 had a reference to a bnode _:XXX, but the bnode was serialized with free floating brackets ('[]') without the id _:XXX.
	my $turtle	= <<'END';
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
@prefix scovo: <http://purl.org/NET/scovo#> .
@prefix void: <http://rdfs.org/ns/void#> .
@prefix ent: <http://www.w3.org/ns/entailment/> .

[]
	a sd:Service ;
	
	sd:url <http://kasei.us/sparql> ;
	
	sd:defaultEntailmentRegime ent:Simple ;
	sd:feature sd:DereferencesURIs ;
	sd:extensionFunction <http://openjena.org/ARQ/function#sha1sum>, <java:com.ldodds.sparql.Distance> ;
	sd:languageExtension <http://kasei.us/2008/04/sparql-extension/federate_bindings> ;
	
	sd:defaultDatasetDescription [
		a sd:Dataset ;
		sd:defaultGraph [
			a sd:Graph ;
			void:statItem [
				scovo:dimension void:numberOfTriples ;
				rdf:value 100
			] ;
		] ;
	] ;
	
	sd:availableGraphDescriptions [
		a sd:GraphCollection ;
		sd:namedGraph [
			a sd:NamedGraph ;
			sd:named <http://xmlns.com/foaf/0.1/> ;
			sd:graphDescription [
				a sd:Graph ;
				void:statItem [
					scovo:dimension void:numberOfTriples ;
					rdf:value 608
				] ;
			] ;
		], [
			a sd:NamedGraph ;
			sd:named <http://kasei.us/sparql> ;
			sd:graphDescription [
				a sd:Graph ;
				void:statItem [
					scovo:dimension void:numberOfTriples ;
					rdf:value 53
				] ;
			] ;
		] ;
	] ;
	
	sd:defaultEntailmentRegime ent:Simple ;
	
	.

<java:com.ldodds.sparql.Distance> a sd:ScalarFunction .
<http://openjena.org/ARQ/function#sha1sum> a sd:ScalarFunction .
END
	my $parser	= RDF::Trine::Parser->new('turtle');
	my $model	= RDF::Trine::Model->temporary_model;
	my $base_uri	= 'http://kasei.us/2009/09/sparql/sd-example.ttl';
	$parser->parse_into_model( $base_uri, $turtle, $model );
	my $namespaces	= {
		rdfs	=> 'http://www.w3.org/2000/01/rdf-schema#',
		xsd		=> 'http://www.w3.org/2001/XMLSchema#',
		scovo	=> 'http://purl.org/NET/scovo#',
		jena	=> 'java:com.hp.hpl.jena.query.function.library.',
		sd		=> 'http://www.w3.org/ns/sparql-service-description#',
		saddle	=> 'http://www.w3.org/2005/03/saddle/#',
		ke		=> 'http://kasei.us/2008/04/sparql-extension/',
		kf		=> 'http://kasei.us/2007/09/functions/',
	};
	my $serializer	= RDF::Trine::Serializer::Turtle->new( $namespaces );
	my $got			= $serializer->serialize_model_to_string($model);
	unlike( $got, qr/\[\] a sd:NamedGraph/sm, 'no free floating blank node' );
}

{
	# bug found 2010.04.08 serialized uri->blank->xxx as uri->bnode label and []->xxx.
	my $turtle	= <<'END';
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dc:      <http://purl.org/dc/terms/> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix foaf:    <http://xmlns.com/foaf/0.1/> .
@prefix void:    <http://rdfs.org/ns/void#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .
@prefix doap:    <http://usefulinc.com/ns/doap#> .
@prefix conv:    <http://data-gov.tw.rpi.edu/vocab/conversion/> .

@prefix dg:      <http://data-gov.tw.rpi.edu/datagov/vocab/> .
@prefix raw:     <http://data-gov.tw.rpi.edu/datagov/dataset/10/vocab/raw/> .
@prefix e1:      <http://data-gov.tw.rpi.edu/datagov/dataset/10/vocab/enrichment/1/> .
@prefix e2:      <http://data-gov.tw.rpi.edu/datagov/dataset/10/vocab/enrichment/2/> .
@prefix :        <http://data-gov.tw.rpi.edu/datagov/dataset/10/> .

:dataset-1 a void:Dataset ;
	conv:conversionProcess [
		a conv:RawConversionProcess ;
		conv:conversionTool [ conv:project <csv2rdf> ; conv:revision "1.0.1" ] ;
		dc:date "2010-01-01T18:00:00Z"^^xsd:dateTime ;
		
		# essential data
		dcterms:requires [ conv:datasetFile <dataset.csv> ; dc:date "2009-12-01"^^xsd:date ; foaf:sha1 "da39a3ee5e6b4b0d3255bfef95601890afd80709" ] ;
		conv:datasetOrigin "datagov" ;
		conv:datasetIdentifier "10" ;
	] ;
	.
END
	my $parser	= RDF::Trine::Parser->new('turtle');
	my $model	= RDF::Trine::Model->temporary_model;
	my $base_uri	= 'http://kasei.us/2009/09/sparql/sd-example.ttl';
	$parser->parse_into_model( $base_uri, $turtle, $model );
	my $namespaces	= {
		rdf		=> 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
		rdfs	=> 'http://www.w3.org/2000/01/rdf-schema#',
		dc		=> 'http://purl.org/dc/terms/',
		dcterms	=> 'http://purl.org/dc/terms/',
		foaf	=> 'http://xmlns.com/foaf/0.1/',
		void	=> 'http://rdfs.org/ns/void#',
		xsd		=> 'http://www.w3.org/2001/XMLSchema#',
		doap	=> 'http://usefulinc.com/ns/doap#',
		conv	=> 'http://data-gov.tw.rpi.edu/vocab/conversion/',
		dg		=> 'http://data-gov.tw.rpi.edu/datagov/vocab/',
	};
	my $serializer	= RDF::Trine::Serializer::Turtle->new( $namespaces );
	my $got			= $serializer->serialize_model_to_string($model);
	unlike( $got, qr/\[\] conv:conversionTool/sm, 'no free floating blank node 2' );
}

{
	my $turtle	= <<'END';
@prefix dc:      <http://purl.org/dc/terms/> .
<http://example.com/> dc:date "2010-01-01T18:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
END
	my $parser	= RDF::Trine::Parser->new('turtle');
	my $model	= RDF::Trine::Model->temporary_model;
	my $base_uri	= 'http://kasei.us/2009/09/sparql/sd-example.ttl';
	$parser->parse_into_model( $base_uri, $turtle, $model );
	my $namespaces	= { xsd => 'http://www.w3.org/2001/XMLSchema#' };
	my $serializer	= RDF::Trine::Serializer::Turtle->new( $namespaces );
	my $got			= $serializer->serialize_model_to_string($model);
	like( $got, qr/"\^\^xsd:dateTime/sm, 'qname literal datatype' );
}

{
	# Date: Sun, 2 Jan 2011 22:17:55 +0000
	# From: Toby Inkster <mail@tobyinkster.co.uk>
	# To: dev@lists.perlrdf.org
	# Subject: Turtle serialisation bug
	# Message-ID: <20110102221755.78db000f@miranda.g5n.co.uk>
	
	my $turtle	= <<"END";
_:a <q> [
	<p> [
		<r> _:b ];
	<t> _:c ] .
# _:a <x> _:b .
_:c <e> _:a .
END

# _:a <q> [
# 	<p> [
# 		<r> _:b ];
# 	<t> [ <e> _:a ] ] ;
# 	<x> _:b .

	my $parser	= RDF::Trine::Parser->new('turtle');
	my $model	= RDF::Trine::Model->temporary_model;
	my $base_uri	= 'http://example.org/';
	$parser->parse_into_model( $base_uri, $turtle, $model );
	my $serializer	= RDF::Trine::Serializer::Turtle->new();
	my $got			= $serializer->serialize_model_to_string($model);
	my $gotmodel	= RDF::Trine::Model->temporary_model;
	$parser->parse_into_model( $base_uri, $got, $gotmodel );
	is( $gotmodel->size, $model->size, 'bnode concise syntax' );
}

{
	my $hash	= {
		'_:a' => {
			'http://example.com/ns#description' => [{type=>'uri', value=>'_:b'}],
		},
		'_:b' => {
			'http://example.com/ns#foo' => [{type=>'literal', value=>'foo'}, 'FOO'],
			'http://example.com/ns#bar' => [{type=>'literal', value=>'bar'}],
		},
	};
	my $expect	= qr{[] <http://example.com/ns#description> [\n\t\t((<http://example.com/ns#bar> "bar" ;\n\t\t<http://example.com/ns#foo> "FOO", "foo")|(<http://example.com/ns#foo> "FOO", "foo" ;\n\t\t<http://example.com/ns#bar> "bar"))\n\t] .\n};
	my $test	= 'blank object with multiple predicates and objects';
	my $model = RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
	$model->add_hashref($hash);
	my $serializer = RDF::Trine::Serializer::Turtle->new();
	my $turtle = $serializer->serialize_model_to_string($model);
	TODO: {
		if ($test =~ /TODO/) {
			local $TODO	= "Not implemented yet";
			like($turtle, $expect, $test);
		} else {
			like($turtle, $expect, $test);
		}
	}
}

done_testing();
