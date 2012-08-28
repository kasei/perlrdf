use Test::More tests => 36;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed refaddr);

use RDF::Trine qw(iri);
use RDF::Trine::Statement::Triple;
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
my $v		= RDF::Trine::Node::Variable->new('v');

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, $rdf->type, $foaf->Document );
	is_deeply( [ $st->node_names ], [qw(subject predicate object)], 'triple node names' );
	is( $st->type, 'TRIPLE' );
	isa_ok( $st, 'RDF::Trine::Statement' );
	isa_ok( $st->subject, 'RDF::Trine::Node::Resource' );
	isa_ok( $st->predicate, 'RDF::Trine::Node::Resource' );
	isa_ok( $st->object, 'RDF::Trine::Node::Resource' );
	is( $st->subject->uri_value, 'http://kasei.us/' );
	is_deeply( [$st->construct_args], [$kasei, $rdf->type, $foaf->Document] );
	
	my $c	= $st->clone;
	cmp_ok( refaddr($st), '!=', refaddr($c), 'cloned statement is a new object' );
	is_deeply( $st, $c, 'cloned statement has the same structure' );
}

{
	my $st		= RDF::Trine::Statement::Quad->new( $kasei, $dc->description, $desc, $myfoaf );
	is_deeply( [ $st->node_names ], [qw(subject predicate object graph)], 'quad node names' );
	is( $st->type, 'QUAD' );
	isa_ok( $st, 'RDF::Trine::Statement::Quad' );
	isa_ok( $st->object, 'RDF::Trine::Node::Literal' );
	isa_ok( $st->graph, 'RDF::Trine::Node::Resource' );
	is( $st->graph->uri_value, 'http://kasei.us/about/foaf.xrdf' );
	$st->graph( $kasei );
	is( $st->graph->uri_value, 'http://kasei.us/' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, undef, undef );
	isa_ok( $st->predicate, 'RDF::Trine::Node::Variable' );
	isa_ok( $st->object, 'RDF::Trine::Node::Variable' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, $rdf->type, $foaf->Document );
	my @nodes	= $st->nodes;
	is( scalar(@nodes), 3, 'triple node count' );
	is_deeply( \@nodes, [$kasei, $rdf->type, $foaf->Document], 'nodes' );
}

{
	my $st		= RDF::Trine::Statement::Quad->new( $kasei, $dc->description, $desc, $myfoaf );
	my @nodes	= $st->nodes;
	is( scalar(@nodes), 4, 'quad node count' );
	is_deeply( \@nodes, [$kasei, $dc->description, $desc, $myfoaf], 'quad nodes' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $a, $b, $a );
	$st->subject( $kasei );
	$st->predicate( $rdf->type );
	$st->object( $foaf->Document );
	is_deeply( [ $st->nodes ], [$kasei, $rdf->type, $foaf->Document], 'nodes after changed triple values' );
}

{
	my $sse		= '(triple <http://kasei.us/about/foaf.xrdf#greg> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document>)';
	my $st_a	= RDF::Trine::Statement::Triple->new( $p, $rdf->type, $foaf->Document );
	my $st_b	= RDF::Trine::Statement::Triple->from_sse( $sse );
	is_deeply( $st_a, $st_b, 'from_sse' );
	is( $sse, $st_a->sse, 'sse comparison' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, $dc->title, $v );
	my @vars	= $st->definite_variables;
	is_deeply( \@vars, [qw(v)], 'definite variables' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, $dc->title, $v );
	my $st2		= $st->clone;
	is_deeply( $st, $st2, 'statement clone' );
}

{
	my $st		= RDF::Trine::Statement::Triple->new( $kasei, $dc->title, $v );
	my $expect	= RDF::Trine::Statement::Triple->new( $kasei, $dc->title, $desc );
	my $st2		= $st->bind_variables({ v => $desc });
	is_deeply( $st2, $expect, 'statement after binding' );
}

throws_ok {
	my $st		= RDF::Trine::Statement::Triple->new();
} qr{required at constructor}, "RDF::Trine::Statement::new throws without 3 node arguments.";

throws_ok {
	my $st		= RDF::Trine::Statement::Quad->new(1,2);
} qr{required at constructor}, "RDF::Trine::Statement::Quad::new throws without 4 node arguments.";


SKIP: {
	eval "use RDF::Redland;";
	skip( "Need RDF::Redland to run these tests.", 5 ) if ($@);
	
	{
		my $subj		= RDF::Redland::Node->new_from_uri("http://example.com/doc");
		my $pred		= RDF::Redland::Node->new_from_uri("http://example.com/maker");
		my $obj			= RDF::Redland::Node->new_from_blank_identifier("eve");
		my $statement	= new RDF::Redland::Statement($subj, $pred, $obj);
		isa_ok( $statement, 'RDF::Redland::Statement' );
		
		my $st	= RDF::Trine::Statement::API->from_redland( $statement );
		isa_ok( $st, 'RDF::Trine::Statement' );
		is( $st->sse, '(triple <http://example.com/doc> <http://example.com/maker> _:eve)', 'triple sse after from_redland' );
	}
	
	{
		my $subj		= RDF::Redland::Node->new_from_uri("http://example.com/doc");
		my $pred		= RDF::Redland::Node->new_from_uri("http://example.com/maker");
		my $obj			= RDF::Redland::Node->new_from_blank_identifier("eve");
		my $statement	= new RDF::Redland::Statement($subj, $pred, $obj);
		
		my $st	= RDF::Trine::Statement::Quad->from_redland( $statement, iri('graph') );
		isa_ok( $st, 'RDF::Trine::Statement::Quad' );
		is( $st->sse, '(quad <http://example.com/doc> <http://example.com/maker> _:eve <graph>)', 'quad sse after from_redland' );
	}
}

