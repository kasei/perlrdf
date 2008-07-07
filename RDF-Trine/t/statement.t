use Test::More tests => 15;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;
use RDF::Trine::Namespace;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $dc		= RDF::Trine::Namespace->new('http://purl.org/dc/elements/1.1/');
my $kasei	= RDF::Trine::Node::Resource->new('http://kasei.us/');
my $a		= RDF::Trine::Node::Blank->new();
my $b		= RDF::Trine::Node::Blank->new();
my $p		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
my $myfoaf	= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf');
my $name	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/name');
my $desc	= RDF::Trine::Node::Literal->new( 'my homepage' );

{
	my $st		= RDF::Trine::Statement->new( $kasei, $rdf->type, $foaf->Document );
	isa_ok( $st, 'RDF::Trine::Statement' );
	isa_ok( $st->subject, 'RDF::Trine::Node::Resource' );
	isa_ok( $st->predicate, 'RDF::Trine::Node::Resource' );
	isa_ok( $st->object, 'RDF::Trine::Node::Resource' );
	is( $st->subject->uri_value, 'http://kasei.us/' );
}

{
	my $st		= RDF::Trine::Statement::Quad->new( $kasei, $dc->description, $desc, $myfoaf );
	isa_ok( $st, 'RDF::Trine::Statement::Quad' );
	isa_ok( $st->object, 'RDF::Trine::Node::Literal' );
	isa_ok( $st->context, 'RDF::Trine::Node::Resource' );
	is( $st->context->uri_value, 'http://kasei.us/about/foaf.xrdf' );
}

{
	my $st		= RDF::Trine::Statement->new( $kasei, undef, undef );
	isa_ok( $st->predicate, 'RDF::Trine::Node::Variable' );
	isa_ok( $st->object, 'RDF::Trine::Node::Variable' );
}

{
	my $st		= RDF::Trine::Statement->new( $kasei, $rdf->type, $foaf->Document );
	my @nodes	= $st->nodes;
	is( scalar(@nodes), 3 );
	is_deeply( \@nodes, [$kasei, $rdf->type, $foaf->Document] );
}

{
	my $st		= RDF::Trine::Statement::Quad->new( $kasei, $dc->description, $desc, $myfoaf );
	my @nodes	= $st->nodes;
	is( scalar(@nodes), 4 );
	is_deeply( \@nodes, [$kasei, $dc->description, $desc, $myfoaf] );
}
