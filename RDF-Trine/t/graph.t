use Test::More tests => 6;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Store;
use RDF::Trine::Model;
use RDF::Trine::Graph;
use RDF::Trine::Parser;


{
	my $foaf_a	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	[] a foaf:Person ; foaf:name "Alice" .
	[] a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	
	my $foaf_b	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	_:alice a foaf:Person ; foaf:name "Alice" .
	_:bob a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	test_graph_equality( $foaf_a, $foaf_b, 1, 'simple blank node map' );
}

{
	my $foaf_a	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	[] a foaf:Person ; foaf:name "Alice" .
	<bob> a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	
	my $foaf_b	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	_:alice a foaf:Person ; foaf:name "Alice" .
	_:bob a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	test_graph_equality( $foaf_a, $foaf_b, 0, 'blank node does not map to iri' );
}


sub test_graph_equality {
	my $rdf_a	= shift;
	my $rdf_b	= shift;
	my $expect	= shift;
	my $name	= shift;
	
	my $model_a	= do {
		my $store	= RDF::Trine::Store->temporary_store();
		my $model	= RDF::Trine::Model->new( $store );
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse_into_model ( 'http://base/', $rdf_a, $model );
		$model;
	};
	
	my $model_b	= do {
		my $store	= RDF::Trine::Store->temporary_store();
		my $model	= RDF::Trine::Model->new( $store );
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse_into_model ( 'http://base/', $rdf_b, $model );
		$model;
	};

	my $graph_a	= RDF::Trine::Graph->new( $model_a );
	my $graph_b	= RDF::Trine::Graph->new( $model_b );

	isa_ok( $graph_a, 'RDF::Trine::Graph' );
	isa_ok( $graph_b, 'RDF::Trine::Graph' );
	is( $graph_a->equals( $graph_b ), $expect, $name );
}
