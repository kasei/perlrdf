use Test::More tests => 8;
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
<rdf:Description rdf:about="http://example.com/doc">
	<predicate xmlns="http://example.com/">Foo</predicate>
</rdf:Description>
<rdf:Description rdf:about="http://example.com/doc">
	<predicate xmlns="http://example.com/" rdf:resource="http://example.com/bar"/>
</rdf:Description>
<rdf:Description rdf:about="http://example.com/doc">
	<predicate xmlns="http://example.com/" xml:lang="en">baz</predicate>
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
<rdf:Description rdf:nodeID="b">
	<description xmlns="http://example.com/ns#">quux</description>
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
<rdf:Description rdf:nodeID="a">
	<title xmlns="http://example.com/ns#">foo</title>
</rdf:Description>
<rdf:Description rdf:nodeID="a">
	<title xmlns="http://example.com/ns#" rdf:datatype="http://www.w3.org/2001/XMLSchema#string">bar</title>
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
<rdf:Description rdf:nodeID="b">
	<description xmlns="http://example.com/ns#" rdf:nodeID="a"/>
</rdf:Description>
</rdf:RDF>
END
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
