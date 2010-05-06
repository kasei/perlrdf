use Test::More tests => 9;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(literal);
use_ok('RDF::Trine::Parser::RDFJSON');

{
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
	
	ok(defined $data->{'http://example.com/doc'}->{'http://example.com/predicate'}->[2]->{'value'}, "as_hashref seems to work");
}

{
	my $json	=<<"END";
{
	"_:a": {
		"http://example.com/predicate":[
			"_:b"
		]
	}
}
END
	my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
	my $model = RDF::Trine::Model->temporary_model;
	$parser->parse_into_model(undef, $json, $model);
	my $p	= RDF::Trine::Node::Resource->new('http://example.com/predicate');
	ok($model->count_statements( undef, $p, undef ), "RDF/JSON parser works");
	
	my @subj	= $model->subjects();
	is( scalar(@subj), 1, 'one subject' );
	isa_ok( $subj[0], 'RDF::Trine::Node::Blank', 'blank node subject' );
	
	my @obj	= $model->objects();
	is( scalar(@obj), 1, 'one object' );
	isa_ok( $obj[0], 'RDF::Trine::Node::Blank', 'blank node obj' );
	isnt( $subj[0], $obj[0], 'different subejct and obejct nodes' );
}

