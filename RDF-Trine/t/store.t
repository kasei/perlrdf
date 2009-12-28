use Test::More tests => 11;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace;

my $store	= RDF::Trine::Store::DBI->temporary_store();
my $model	= RDF::Trine::Model->new( $store );
isa_ok( $store, 'RDF::Trine::Store::DBI' );


my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $h		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $h, $foaf->name, RDF::Trine::Node::Literal->new('Alice') );
my $st1		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st3		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Gregory') );
my $st4		= RDF::Trine::Statement->new( $g, $foaf->homepage, RDF::Trine::Node::Resource->new('http://kasei.us/') );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3, $st4);

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person );
	my $p	= RDF::Trine::Pattern->new( $t );
	
	my $iter	= $model->get_pattern( $p );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	
	my (@rows)	= $iter->get_all;
	is_deeply( \@rows, [ { x => $g } ], '1-triple get_pattern results' );
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

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person );
	my $p	= RDF::Trine::Pattern->new( $t );
	
	my $iter	= RDF::Trine::Store::get_pattern( $model, $p );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	
	my (@rows)	= $iter->get_all;
	is_deeply( \@rows, [ { x => $g } ], '1-triple get_pattern results' );
}

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $n	= RDF::Trine::Node::Variable->new( 'name' );
	my $p	= RDF::Trine::Pattern->new(
		RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person ),
		RDF::Trine::Statement->new( $x, $foaf->name, $n ),
	);
	
	my $iter	= RDF::Trine::Store::get_pattern( $model, $p );
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
