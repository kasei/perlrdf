use Test::More tests => 41;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';

use DBI;
use RDF::Trine qw(iri blank literal);
use RDF::Trine::Model;
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Namespace;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement;
use File::Temp qw(tempfile);

my $default	= RDF::Trine::Node::Nil->new;
my $ex		= RDF::Trine::Namespace->new('http://example.com/');
my $st0		= RDF::Trine::Statement->new( $ex->a, $ex->p, literal('default') );
my $st1		= RDF::Trine::Statement::Quad->new( $ex->a, $ex->p, literal('g1'), $ex->g1 );
my $st2		= RDF::Trine::Statement::Quad->new( $ex->a, $ex->r, literal('g2'), $ex->g2 );
my $st3		= RDF::Trine::Statement::Quad->new( $ex->a, $ex->r, literal('g3'), $ex->g3 );
my $st4		= RDF::Trine::Statement::Quad->new( $ex->a, $ex->r, literal('g3.2'), $ex->g3 );

my $store	= RDF::Trine::Store->temporary_store;
my $model	= RDF::Trine::Model->new( $store );
isa_ok( $model, 'RDF::Trine::Model' );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3, $st4);

count_tests( $model );
get_statements_tests( $model );
get_statements_union_graph( $model );

sub get_statements_union_graph {
	my $model	= shift;
	is( $model->count_statements( undef, $ex->r, undef, undef ), 3, 'count of statements with undef context' );
	is( $model->count_statements( undef, $ex->r, undef, $ex->g2 ), 1, 'count of statements with iri context' );
	is( $model->count_statements( undef, $ex->r, undef, iri('tag:gwilliams@cpan.org,2010-01-01:RT:ALL') ), 3, 'count of statements with special union-graph iri' );
}

sub count_tests {
	my $_model	= shift;
	my $model	= RDF::Trine::Model::Dataset->new( $_model );
	
	my $expected_msize	= 5;
	
	print "# base model (default dataset)\n";
	is( $model->count_statements( undef, undef, literal('default'), $default ), 1, 'count statements from actual default graph' );
	count_test_1( $model, $expected_msize, 1, 2 );
	
	print "# empty default dataset\n";
	$model->push_dataset();
	is( $model->count_statements( undef, undef, undef, $default ), 0, 'count statements from empty dataset' );
	count_test_1( $model, 0, 0, 0 );
	
	print "# 1-graph default dataset\n";
	$model->push_dataset( default => [ $ex->g1 ] );
	is( $model->count_statements( undef, undef, undef, $default ), 1, 'count statements from dataset with masked 1-graph default graph' );
	count_test_2( $model, literal('g1') => 1 );
	count_test_2( $model, literal('g2') => 0 );
	count_test_2( $model, literal('g3') => 0 );
	
	print "# 2-graph default dataset\n";
	$model->push_dataset( default => [ $ex->g1, $ex->g3 ] );
	is( $model->count_statements( undef, undef, undef, $default ), 3, 'count statements from dataset with masked 2-graph default graph' );
	count_test_2( $model, literal('g1') => 1 );
	count_test_2( $model, literal('g2') => 0 );
	count_test_2( $model, literal('g3') => 1 );
	
	print "# reverting to 1-graph default dataset\n";
	$model->pop_dataset;
	is( $model->count_statements( undef, undef, undef, $default ), 1, 'count statements from dataset with masked 1-graph default graph' );
	count_test_2( $model, literal('g1') => 1 );
	count_test_2( $model, literal('g2') => 0 );
	count_test_2( $model, literal('g3') => 0 );
}

sub get_statements_tests {
	my $_model	= shift;
	my $model	= RDF::Trine::Model::Dataset->new( $_model );
	print "# get_statements\n";
	
	{
		my $iter	= $model->get_statements;
		my %expect	= (map { $_ => 1 } qw(default g1 g2 g3 g3.2));
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, \%expect, 'expected triple results on default dataset' );
	}
	{
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my $expect	= {
			'(nil)'						=> 1,
			'<http://example.com/g1>'	=> 1,
			'<http://example.com/g2>'	=> 1,
			'<http://example.com/g3>'	=> 2,
		};
		my %got;
		while (my $row = $iter->next) {
			isa_ok( $row, 'RDF::Trine::Statement::Quad' );
			$got{ $row->context->as_string }++;
		}
		is_deeply( \%got, $expect, 'expected quad results on default dataset' );
	}
	
	$model->push_dataset( default => [ $ex->g1 ] );
	
	{
		my $expect	= {
			'g1'	=> 1,
		};
		my %got;
		my $iter	= $model->get_statements;
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, $expect, 'expected triple results on 1-graph default dataset' );
	}
	{
		my $expect	= {
			'(nil)'	=> 1,
		};
		my %got;
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		while (my $row = $iter->next) {
			$got{ $row->context->as_string }++;
		}
		is_deeply( \%got, $expect, 'expected quad results on 1-graph default dataset' );
	}
	{
		my $expect	= { map { $_ => 1 } qw(g1) };
		my %got;
		my $iter	= $model->get_statements( undef, undef, undef, $default );
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, $expect, 'expected default quad results on 1-graph default dataset' );
	}
	
	$model->push_dataset( default => [ $ex->g1, $ex->g3 ] );
	
	{
		my $iter	= $model->get_statements;
		my $expect	= {
			'g1'						=> 1,
			'g3'						=> 1,
			'g3.2'						=> 1,
		};
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, $expect, 'expected triple results on 2-graph default dataset' );
	}
	{
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my $expect	= {
			'(nil)'	=> 3,
		};
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->context->as_string }++;
		}
		is_deeply( \%got, $expect, 'expected quad results on 2-graph default dataset' );
	}
	{
		my $iter	= $model->get_statements( undef, undef, undef, $default );
		my $expect	= { map { $_ => 1 } qw(g1 g3 g3.2) };
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, $expect, 'expected default quad results on 2-graph default dataset' );
	}
	
	$model->push_dataset( default => [ $ex->g1, $ex->g3 ], named => [ $ex->g2 ] );
	
	{
		my $iter	= $model->get_statements;
		my $expect	= {
			'g1'						=> 1,
			'g2'						=> 1,
			'g3'						=> 1,
			'g3.2'						=> 1,
		};
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->object->literal_value }++;
		}
		is_deeply( \%got, $expect, 'expected triple results on 2-graph default, 1 named graph dataset' );
	}
	{
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my $expect	= {
			'(nil)'						=> 3,
			'<http://example.com/g2>'	=> 1,
		};
		my %got;
		while (my $row = $iter->next) {
			$got{ $row->context->as_string }++;
		}
		is_deeply( \%got, $expect, 'expected quad results on 2-graph default, 1 named graph dataset' );
	}
}


sub count_test_1 {
	my $model	= shift;
	my $msize	= shift;
	my $dsize	= shift;
	my $psize	= shift;
	is( $model->count_statements(undef, undef, undef, undef), $msize, 'model size' );
	is( $model->count_statements(undef, undef, undef, $default), $dsize, 'default graph size' );
	is( $model->count_statements(), $msize, 'full model size' );
	is( $model->count_statements( undef, $ex->p, undef ), $psize, 'count of ex:p statements in union' );
}

sub count_test_2 {
	my $model	= shift;
	my $node	= shift;
	my $expect	= shift;
	my $count	= $model->count_statements(undef, undef, $node, $default);
	is( $count, $expect, "expected object count for " . $node->as_string );
}
