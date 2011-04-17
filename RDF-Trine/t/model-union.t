use Test::More tests => 9;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use DBI;
use RDF::Trine;
use RDF::Trine::Model::Union;
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Namespace;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement;
use File::Temp qw(tempfile);

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $h		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $h, $foaf->name, RDF::Trine::Node::Literal->new('Alice') );
my $st1		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st3		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Gregory') );

my $store1	= RDF::Trine::Store::DBI->temporary_store();
my $store2	= RDF::Trine::Store::DBI->temporary_store();
my $model	= RDF::Trine::Model::Union->new( $store1, $store2 );

$store1->add_statement( $_ ) for ($st0, $st1);
$store2->add_statement( $_ ) for ($st2);
$model->add_statement( $st3 );

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person );
	my $p	= RDF::Trine::Pattern->new( $t );
	
	my $iter	= $model->get_pattern( $p );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	
	my (@rows)	= $iter->get_all;
	is_deeply( \@rows, [ RDF::Trine::VariableBindings->new({ x => $g }) ], '1-triple get_pattern results' );
}

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $n	= RDF::Trine::Node::Variable->new( 'name' );
	my $p	= RDF::Trine::Pattern->new(
		RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person ),
		RDF::Trine::Statement->new( $x, $foaf->name, $n ),
	);
	
	my $iter	= $model->get_pattern( $p );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	
	my %got;
	my $count	= 0;
	while (my $row = $iter->next) {
		$got{ $row->{'name'}->literal_value }++;
		$count++;
	}
	my $expect	= { qw(Greg 1 Gregory 1) };
	is( $count, 2, 'expected result count' );
	is_deeply( \%got, $expect, '2-triple get_pattern results' );
}

$model->remove_statement( $st3 );

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $n	= RDF::Trine::Node::Variable->new( 'name' );
	my $p	= RDF::Trine::Pattern->new(
		RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person ),
		RDF::Trine::Statement->new( $x, $foaf->name, $n ),
	);
	
	my $iter	= $model->get_pattern( $p );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	
	my %got;
	my $count	= 0;
	while (my $row = $iter->next) {
		$got{ $row->{'name'}->literal_value }++;
		$count++;
	}
	my $expect	= { qw(Greg 1) };
	is( $count, 1, 'expected result count' );
	is_deeply( \%got, $expect, '2-triple get_pattern results' );
}

$model->remove_statements( $g, undef, undef );
is( $model->size, 1, 'model size after remove_statements' );
