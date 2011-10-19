use Test::More tests => 14;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);

use RDF::Trine;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Pattern;

my $store	= RDF::Trine::Store->temporary_store();
my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, RDF::Trine::Node::Resource->new('http://kasei.us/') );
$store->add_statement( $_ ) for ($st0, $st1, $st2);


{
	my $pattern;
	lives_ok { $pattern	= RDF::Trine::Pattern->new() } 'RDF::Trine::Pattern::new lives on no arguments';
	isa_ok( $pattern, 'RDF::Trine::Pattern' );
}

throws_ok { RDF::Trine::Pattern->new(1) } 'RDF::Trine::Error', 'RDF::Trine::Pattern::new throws on non-blessed arguments';
throws_ok { RDF::Trine::Pattern->new($store) } 'RDF::Trine::Error', 'RDF::Trine::Pattern::new throws on non-triple arguments';

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person );
	my $p	= RDF::Trine::Pattern->new( $t );
	isa_ok( $p, 'RDF::Trine::Pattern' );
	is_deeply( [ $p->construct_args ], [ $t ], 'construct args' );
	is_deeply( [ $p->definite_variables ], ['x'], 'definite_variables' );
	my $q	= $p->clone;
	cmp_ok( refaddr($p), '!=', refaddr($q), 'clone returns different object' );
	is_deeply( $p, $q, 'cloned structure is the same' );
	
	ok( $p->subsumes( $t ), 'fbb subsumes fbb' );
	ok( $p->subsumes( $st0 ), 'fbb subsumes bbb' );
}

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $y	= RDF::Trine::Node::Variable->new( 'y' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $y );
	my $p	= RDF::Trine::Pattern->new( $t );

	my $u	= RDF::Trine::Statement->new( $x, $rdf->type, $foaf->Person );
	my $v	= RDF::Trine::Statement->new( $g, $x, $foaf->Person );
	ok( $p->subsumes( $u ), 'fbf subsumes fbb' );
	ok( not( $p->subsumes( $v ) ), 'fbf does not subsume bfb' );
}

{
	my $x	= RDF::Trine::Node::Variable->new( 'x' );
	my $y	= RDF::Trine::Node::Variable->new( 'y' );
	my $t	= RDF::Trine::Statement->new( $x, $rdf->type, $y );
	my $p	= RDF::Trine::Pattern->new( $t );
	my $q	= $p->bind_variables( { 'x' => $g, 'y' => $foaf->Person } );
	ok( $q->subsumes( $st0 ), 'bind_variables' );
}
