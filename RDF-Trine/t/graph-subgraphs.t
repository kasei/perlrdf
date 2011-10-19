use Test::More tests => 30;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri);
use RDF::Trine::Store;
use RDF::Trine::Model;
use RDF::Trine::Graph;
use RDF::Trine::Parser;

ok(RDF::Trine::Graph->can('is_subgraph_of'), 'RDF::Trine::Graph provides is_subgraph_of');

{
	my $foaf_a	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	<alice> foaf:knows <eve> .
END
	
	my $foaf_b	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	<alice> foaf:knows <eve> .
	<bob> foaf:knows <eve> .
END

	test_graph_subset( $foaf_a, $foaf_b, 1, 'subgraph with no blank nodes' );
}

### Expecting exceptions
{
	my $rdf	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	[] a foaf:Person ; foaf:name "Alice" .
	[] a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	my $store	= RDF::Trine::Store->temporary_store();
	my $model	= RDF::Trine::Model->new( $store );
	my $parser	= RDF::Trine::Parser->new('turtle');
	$parser->parse_into_model ( 'http://base/', $rdf, $model );
	my $graph	= RDF::Trine::Graph->new( $model );
	throws_ok { $graph->is_subgraph_of( 1 ) } 'RDF::Trine::Error::MethodInvocationError', "RDF::Trine::Graph::is_subgraph_of throws on unblessed arguments";
	throws_ok { $graph->is_subgraph_of( bless({},'Foo') ) } 'RDF::Trine::Error::MethodInvocationError', "RDF::Trine::Graph::is_subgraph_of throws on weirdly blessed arguments";
}


### 
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
	_:bob a foaf:Person ; foaf:name "Bob" , "Robert" .
	_:carol a foaf:Person ; foaf:name "Carol" .
	<x> <y> <z> .
END
	test_graph_subset( $foaf_a, $foaf_b, 1, 'simple blank node map' );
}

{
	my $foaf_a	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	[] a foaf:Person ; foaf:name "Alice" .
	[] a foaf:Person ; foaf:name "Bob" ; foaf:homepage [] .
	<x> <y> <z> .
END
	
	my $foaf_b	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	_:alice a foaf:Person ; foaf:name "Alice" .
	_:bob a foaf:Person ; foaf:name "Bob" ; foaf:homepage <http://example.net> .
	<x> <y> <z> , <zz> .
END
	test_graph_subset( $foaf_a, $foaf_b, 0, 'blank node does not map to iri' );
}

{
	my $foaf_a	= "<x> <y> <z> .\n";
	my $foaf_b	= "<a> <b> <c> .\n";
	test_graph_subset( $foaf_a, $foaf_b, 0, 'different non-blank statements' );
}

{
	my $foaf_a	= "_:a <knows> _:a .\n";
	my $foaf_b	= "_:a <knows> _:b .\n";
	test_graph_subset( $foaf_a, $foaf_b, 0, 'different number of blank nodes' );
}

{
	my $foaf_a	= "_:a <knows> _:a .\n";
	my $foaf_b	= "_:a <knows> _:b, _:c.\n";
	test_graph_subset( $foaf_a, $foaf_b, 0, 'different number of blank statements' );
}

#####################

{
	my $foaf_a	= <<'END';
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	[] a foaf:Person ; foaf:name "Alice" .
	<bob> a foaf:Person ; foaf:name "Bob" .
	<x> <y> <z> .
END
	my $parser	= RDF::Trine::Parser->new('turtle');
	my $model	= RDF::Trine::Model->new( RDF::Trine::Store->temporary_store() );
	$parser->parse_into_model( 'http://base/', $foaf_a, $model );
	my $iter	= $model->get_statements( undef, iri('http://xmlns.com/foaf/0.1/name'), undef );
	my $graph	= RDF::Trine::Graph->new( $iter );
	
	my $model_expect	= do {
		my $store	= RDF::Trine::Store->temporary_store();
		my $model	= RDF::Trine::Model->new( $store );
		$parser->parse_into_model ( 'http://base/', <<'END', $model );
			@prefix foaf: <http://xmlns.com/foaf/0.1/> .
			[] a foaf:Person ; foaf:name "Alice" .
			<bob> a foaf:Person ; foaf:name "Bob" , "Robert" .
			[] foaf:name "Carol" .
			<x> <y> <z> , <w> .
END
		$model;
	};
	my $graph_expect	= RDF::Trine::Graph->new( $model_expect );
	
	ok( $graph->is_subgraph_of( $graph_expect ), 'subgraph from statement iterator' );
	ok( ($graph lt $graph_expect), 'overloaded lt' );
	ok( ($graph_expect gt $graph), 'overloaded gt' );
	ok( ($graph le $graph_expect), 'overloaded le' );
	ok( ($graph_expect ge $graph), 'overloaded ge' );
	ok(!($graph lt $graph), 'lt: not true when graphs equal' );
	ok(!($graph gt $graph), 'gt: not true when graphs equal' );
	ok( ($graph le $graph), 'le: true when graphs equal' );
	ok( ($graph ge $graph), 'ge: true when graphs equal' );
}

sub test_graph_subset {
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
	is( $graph_a->is_subgraph_of( $graph_b ), $expect, $name );
}
