use Test::More tests => 16;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';

use RDF::Query;

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Model::Rules;
use RDF::Trine::Node;
use RDF::Trine::Namespace qw(rdf rdfs);

my @statements	= (
	statement(iri('s'), iri('p'), iri('o')),
	statement(iri('o'), iri('p'), iri('o2')),
	statement(iri('o2'), iri('p'), iri('o3')),
);

{
	my $model	= RDF::Trine::Model::Rules->temporary_model;
	isa_ok( $model, 'RDF::Trine::Model::Rules' );
	my $rule	= RDF::Query->new('CONSTRUCT {<s> <p> <o>} WHERE {}');
	$model->add_rule( $rule );
	$model->run_rules();
	is( $model->count_statements, 1, 'model size after constant rule' );
	{
		my @graphs	= $model->get_contexts->get_all;
		is( scalar(@graphs), 1, 'expected graph count after constant rule' );
	}
	$model->run_rules( named_graph => iri('g') );
	{
		my @graphs	= $model->get_contexts->get_all;
		is( scalar(@graphs), 2, 'expected graph count after named-graph constant rule application' );
	}
}

{
	my $model	= RDF::Trine::Model::Rules->temporary_model;
	$model->add_statement( $_ ) for ($statements[0]);
	is( $model->count_statements, 1, 'model size before inverse rule' );
	my $rule	= RDF::Query->new('CONSTRUCT {?s ?p ?o} WHERE {?o ?p ?s}');
	$model->add_rule( $rule );
	$model->run_rules();
	is( $model->count_statements, 2, 'model size after inverse rule' );
	is( $model->count_statements(iri('o'), iri('p'), iri('s')), 1, 'expected new inverse triple' );
}

{
	my $model	= RDF::Trine::Model::Rules->temporary_model;
	$model->add_statement( $_ ) for (@statements);
	is( $model->count_statements, 3, 'model size before transitive rule' );
	my $rule	= RDF::Query->new('CONSTRUCT {?s <p> ?o} WHERE {?s <p> [ <p> ?o ]}');
	$model->add_rule( $rule );
	$model->run_rules();
	is( $model->count_statements, 6, 'model size after transitive rule' );
}

{
	my $model	= RDF::Trine::Model::Rules->temporary_model;
	$model->add_statement( $_ ) for (@statements);
	is( $model->count_statements, 3, 'model size before 2-step rule' );
	my $rule1	= RDF::Query->new('CONSTRUCT {<o> <p2> ?o} WHERE {<o> <p> ?o}');
	my $rule2	= RDF::Query->new('CONSTRUCT {?s <p3> ?o} WHERE {?s <p2> ?o}');
	$model->add_rule($_) for ( $rule1, $rule2 );
	$model->run_rules();
	is( $model->count_statements, 5, 'model size after 2-step rule' );
	is( $model->count_statements(undef, iri('p3'), undef), 1, 'expected new triple after 2-step rule' );
}

{
	my $parser	= RDF::Trine::Parser->new('ntriples');
	my $model	= RDF::Trine::Model::Rules->temporary_model;
	$parser->parse_into_model('http://base/', <<"END", $model);
<http://example.org/bar> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://example.org/bar> .
<http://example.org/bar> <http://www.w3.org/2000/01/rdf-schema#domain> <http://example.org/Domain1> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#domain> <http://example.org/Domain2> .
<http://example.org/bar> <http://www.w3.org/2000/01/rdf-schema#range> <http://example.org/Range1> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#range> <http://example.org/Range2> .
<http://example.org/baz1> <http://example.org/bas> <http://example.org/baz2> .
END
	$model->add_rdfs_rules();
	$model->run_rules();
	my $ex	= RDF::Trine::Namespace->new('http://example.org/');
	is( $model->count_statements($ex->baz1, $rdf->type, $ex->Domain1), 1, 'expected RDFS entailed triple 1' );
	is( $model->count_statements($ex->baz1, $rdf->type, $ex->Domain2), 1, 'expected RDFS entailed triple 2' );
	is( $model->count_statements($ex->baz2, $rdf->type, $ex->Range1), 1, 'expected RDFS entailed triple 3' );
	is( $model->count_statements($ex->baz2, $rdf->type, $ex->Range2), 1, 'expected RDFS entailed triple 4' );
}

__END__

my $iter	= $model->as_stream;
while (my $st = $iter->next) {
	warn $st->as_string;
}
