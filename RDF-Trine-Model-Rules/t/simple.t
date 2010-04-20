use Test::More tests => 12;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';

use RDF::Query;

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Model::Rules;
use RDF::Trine::Node;
use RDF::Trine::Namespace;

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

__END__

my $iter	= $model->as_stream;
while (my $st = $iter->next) {
	warn $st->as_string;
}
