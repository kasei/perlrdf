use Test::More tests => 22;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri statement);
use_ok('RDF::Trine::Serializer::RDFXML');


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
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/" rdf:about="http://example.com/doc">
	<ns1:predicate rdf:resource="http://example.com/bar"/>
	<ns1:predicate>Foo</ns1:predicate>
	<ns1:predicate xml:lang="en">baz</ns1:predicate>
</rdf:Description>
</rdf:RDF>
END
	
	{
		my $xml = $serializer->serialize_model_to_string($model);
		is($xml, $expect, 'serialize_model_to_string 1');
	}
	{
		my $iter	= $model->as_stream;
		my $xml = $serializer->serialize_iterator_to_string($iter);
		is($xml, $expect, 'serialize_iterator_to_string 1');
	}
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'./doc' => {
			'./predicate' => [
				{'type' => 'literal','value' => 'Foo'},
				{'type' => 'uri','value' => './bar'},
				'baz@en'
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new( base_uri => 'http://example.org/');
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xml:base="http://example.org/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="./" rdf:about="./doc">
	<ns1:predicate rdf:resource="./bar"/>
	<ns1:predicate>Foo</ns1:predicate>
	<ns1:predicate xml:lang="en">baz</ns1:predicate>
</rdf:Description>
</rdf:RDF>
END
	
	{
		my $xml = $serializer->serialize_model_to_string($model);
		is($xml, $expect, 'serialize_model_to_string 1');
	}
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:b' => {
			'http://example.com/ns#description' => ['quux'],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $xml = $serializer->serialize_model_to_string($model);
	
	is($xml, <<"END", 'serialize_model_to_string 2: simple literal');
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/ns#" rdf:nodeID="b">
	<ns1:description>quux</ns1:description>
</rdf:Description>
</rdf:RDF>
END
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:a' => {
			'http://example.com/ns#title' => [
				'foo',
				{type => 'literal', value => 'bar', datatype => 'http://www.w3.org/2001/XMLSchema#string'},
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $xml = $serializer->serialize_model_to_string($model);
	
	is($xml, <<"END", 'serialize_model_to_string 3: datatype literal');
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/ns#" rdf:nodeID="a">
	<ns1:title rdf:datatype="http://www.w3.org/2001/XMLSchema#string">bar</ns1:title>
	<ns1:title>foo</ns1:title>
</rdf:Description>
</rdf:RDF>
END
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:b' => {
			'http://example.com/ns#description' => [{type=>'uri', value=>'_:a'}],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $xml = $serializer->serialize_model_to_string($model);
	
	is($xml, <<"END", 'serialize_model_to_string 4: blank object');
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/ns#" rdf:nodeID="b">
	<ns1:description rdf:nodeID="a"/>
</rdf:Description>
</rdf:RDF>
END
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/alice' => {
			'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' => [{ type => 'resource', value => 'http://xmlns.com/foaf/0.1/Person' }],
			'http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters' => ['en'],
			'http://xmlns.com/foaf/0.1/name' => [ 'Alice', {'type' => 'literal','value' => 'Alice', language => 'en' } ],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://purl.org/net/inkel/rdf/schemas/lang/1.1#" xmlns:ns2="http://xmlns.com/foaf/0.1/" rdf:about="http://example.com/alice">
	<ns1:masters>en</ns1:masters>
	<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Person"/>
	<ns2:name>Alice</ns2:name>
</rdf:Description>
</rdf:RDF>
END
	
	my $xml = $serializer->serialize_model_to_string($model);
	is($xml, $expect, 'serialize_model_to_string 5: multiple namespaces');
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:b' => {
			'http://example.com/' => [{type=>'uri', value=>'_:a'}],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	throws_ok {
		my $xml = $serializer->serialize_model_to_string($model);
	} 'RDF::Trine::Error::SerializationError', "serializing bad predicates throws exception (uri ends with '/')";
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:b' => {
			'http://example.com/123' => [{type=>'uri', value=>'_:a'}],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	throws_ok {
		my $xml = $serializer->serialize_model_to_string($model);
		warn $xml;
	} 'RDF::Trine::Error::SerializationError', "serializing bad predicates throws exception (local part starts with digits)";
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
		'http://example.com/bar' => {
			'http://example.com/predicate' => [
				{'type' => 'literal','value' => 'Bar'},
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/" rdf:about="http://example.com/bar">
	<ns1:predicate>Bar</ns1:predicate>
</rdf:Description>
<rdf:Description xmlns:ns1="http://example.com/" rdf:about="http://example.com/doc">
	<ns1:predicate rdf:resource="http://example.com/bar"/>
	<ns1:predicate>Foo</ns1:predicate>
	<ns1:predicate xml:lang="en">baz</ns1:predicate>
</rdf:Description>
</rdf:RDF>
END
	
	{
		my $xml = $serializer->serialize_model_to_string($model);
		is($xml, $expect, 'serialize_model_to_string 1');
	}
	{
		my $iter	= $model->as_stream;
		my $xml = $serializer->serialize_iterator_to_string($iter);
		is($xml, $expect, 'serialize_iterator_to_string 1');
	}
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/maker' => [
				{'type' => 'uri','value' => '_:a'},
			],
		},
		'_:a' => {
			'http://example.com/name' => [
				{'type' => 'literal','value' => 'Alice', 'lang' => 'en'},
			],
			'http://example.com/homepage' => [
				{'type' => 'uri', 'value' => 'http://example.com/' },
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/" rdf:about="http://example.com/doc">
	<ns1:maker rdf:nodeID="a"/>
</rdf:Description>
<rdf:Description xmlns:ns1="http://example.com/" rdf:nodeID="a">
	<ns1:homepage rdf:resource="http://example.com/"/>
	<ns1:name xml:lang="en">Alice</ns1:name>
</rdf:Description>
</rdf:RDF>
END
	
	my $iter	= $model->bounded_description( iri('http://example.com/doc') );
	my $xml		= $serializer->serialize_iterator_to_string( $iter );
	is($xml, $expect, 'serialize bounded description 1');
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/maker' => [
				{'type' => 'uri','value' => '_:a'},
			],
			'http://example.com/creator' => [
				{'type' => 'uri','value' => '_:a'},
			],
		},
		'_:a' => {
			'http://example.com/name' => [
				{'type' => 'literal','value' => 'Alice', 'lang' => 'en'},
			],
			'http://example.com/homepage' => [
				{'type' => 'uri', 'value' => 'http://example.com/' },
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:ns1="http://example.com/" rdf:about="http://example.com/doc">
	<ns1:creator rdf:nodeID="a"/>
	<ns1:maker rdf:nodeID="a"/>
</rdf:Description>
<rdf:Description xmlns:ns1="http://example.com/" rdf:nodeID="a">
	<ns1:homepage rdf:resource="http://example.com/"/>
	<ns1:name xml:lang="en">Alice</ns1:name>
</rdf:Description>
</rdf:RDF>
END
	
	my $iter	= $model->bounded_description( iri('http://example.com/doc') );
	my $xml		= $serializer->serialize_iterator_to_string( $iter );
	is($xml, $expect, 'serialize bounded description 2');
}

{
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/maker' => [
				{'type' => 'uri','value' => '_:a'},
			],
			'http://example.com/creator' => [
				{'type' => 'uri','value' => '_:a'},
			],
		},
		'_:a' => {
			'http://example.com/name' => [
				{'type' => 'literal','value' => 'Alice', 'lang' => 'en'},
			],
			'http://example.com/homepage' => [
				{'type' => 'uri', 'value' => 'http://example.com/' },
			],
		},
	});
	
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
</rdf:RDF>
END
	
	my $iter	= $model->bounded_description( iri('http://example.com/unknown') );
	my $xml		= $serializer->serialize_iterator_to_string( $iter );
	is($xml, $expect, 'serialize bounded description with unknown node');
}

{
	my $model = RDF::Trine::Model->temporary_model();
	my $serializer = RDF::Trine::Serializer::RDFXML->new();
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
</rdf:RDF>
END
	
	my $xml = $serializer->serialize_model_to_string($model);
	is($xml, $expect, 'serialize_model_to_string with empty model');
}

{
	my $serializer = RDF::Trine::Serializer::RDFXML->new( namespaces => { ex => 'http://example.com/' } );
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/maker' => [
				{'type' => 'uri','value' => '_:a'},
			],
		},
		'_:a' => {
			'http://example.com/name' => [
				{'type' => 'literal','value' => 'Alice', 'lang' => 'en'},
			],
			'http://example.com/homepage' => [
				{'type' => 'uri', 'value' => 'http://example.com/' },
			],
		},
	});
	
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.com/">
<rdf:Description rdf:about="http://example.com/doc">
	<ex:maker rdf:nodeID="a"/>
</rdf:Description>
<rdf:Description rdf:nodeID="a">
	<ex:homepage rdf:resource="http://example.com/"/>
	<ex:name xml:lang="en">Alice</ex:name>
</rdf:Description>
</rdf:RDF>
END
	
	my $iter	= $model->bounded_description( iri('http://example.com/doc') );
	my $xml		= $serializer->serialize_iterator_to_string( $iter );
	is($xml, $expect, 'xmlns namespaces 1');
}

{
	my $serializer = RDF::Trine::Serializer::RDFXML->new( namespaces => {
		foaf	=> 'http://xmlns.com/foaf/0.1/',
		rdfs	=> "http://www.w3.org/2000/01/rdf-schema#",
		lang	=> "http://purl.org/net/inkel/rdf/schemas/lang/1.1#",
	} );
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'_:a' => {
			'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'	=> [{type => 'uri', value => 'http://xmlns.com/foaf/0.1/Person'}],
			'http://xmlns.com/foaf/0.1/name'	=> ['Eve'],
			'http://purl.org/net/inkel/rdf/schemas/lang/1.1#masters' => ['en','fr'],
			'http://www.w3.org/2000/01/rdf-schema#seeAlso'	=> [{type => 'uri', value => 'http://eve.example.com/'}],
		},
	});
	
	my $xml = $serializer->serialize_model_to_string($model);
	like( $xml, qr[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:lang="http://purl.org/net/inkel/rdf/schemas/lang/1.1#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"]sm, 'xmlns sorted in rdf:RDF tag' );
	like( $xml, qr[<lang:masters>en</lang:masters>]sm, 'Qname literal tag' );
	like( $xml, qr[<rdfs:seeAlso rdf:resource="http://eve.example.com/"/>]sm, 'Qname resource tag' );
}

{
	my $serializer	= RDF::Trine::Serializer::RDFXML->new();
	my $model		= RDF::Trine::Model->temporary_model;
	my $base_uri		= 'http://example.org/';
	my $url_with_amp	= "$base_uri?foo=bar&doz=baz";
	$model->add_statement( statement( iri($base_uri), iri("http://xmlns.com/foaf/0.1/page"), iri($url_with_amp) ) );
	
	my $xml = $serializer->serialize_model_to_string($model);
	like( $xml, qr[&amp;]sm, 'XML entity escaping' );
}

{
	my $serializer = RDF::Trine::Serializer::RDFXML->new( scoped_namespaces => 1, namespaces => { ex => 'http://example.com/', unused1 => 'http://example.org/not-used', unused2 => 'tag:kasei.us,2012-01-01:' } );
	my $model = RDF::Trine::Model->temporary_model;
	$model->add_hashref({
		'http://example.com/doc' => {
			'http://example.com/maker' => [
				{'type' => 'uri','value' => '_:a'},
			],
		},
		'_:a' => {
			'http://example.com/name' => [
				{'type' => 'literal','value' => 'Alice', 'lang' => 'en'},
			],
			'http://example.com/homepage' => [
				{'type' => 'uri', 'value' => 'http://example.com/' },
			],
		},
	});
	
	my $expect	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="http://example.com/doc">
	<ex:maker xmlns:ex="http://example.com/" rdf:nodeID="a"/>
</rdf:Description>
<rdf:Description rdf:nodeID="a">
	<ex:homepage xmlns:ex="http://example.com/" rdf:resource="http://example.com/"/>
	<ex:name xmlns:ex="http://example.com/" xml:lang="en">Alice</ex:name>
</rdf:Description>
</rdf:RDF>
END
	
	my $iter	= $model->bounded_description( iri('http://example.com/doc') );
	my $xml		= $serializer->serialize_iterator_to_string( $iter );
	is($xml, $expect, 'xmlns namespaces 2 with unused definitions');
}
