use Test::More tests => 15;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri);
use_ok('RDF::Trine::Serializer::RDFXML');


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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	
	my $xml = $serializer->_serialize_bounded_description($model, iri('http://example.com/doc'));
	is($xml, $expect, 'serialize_model_to_string 1');
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	
	my $xml = $serializer->_serialize_bounded_description($model, iri('http://example.com/doc'));
	is($xml, $expect, '_serialize_bounded_description');
}

{
	my $model = RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
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
	
	my $xml = $serializer->_serialize_bounded_description($model, iri('http://example.com/unknown'));
	is($xml, $expect, '_serialize_bounded_description with unknown node');
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
