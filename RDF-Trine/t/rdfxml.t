use Test::More tests => 9;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
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
