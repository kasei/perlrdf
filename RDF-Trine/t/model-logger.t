use Test::More;
use RDF::Trine::Exporter::RDFPatch;

use strict;
use warnings;
use RDF::Trine;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $HEADER	= qq[\@prefix foaf: <http://xmlns.com/foaf/0.1/> .\n\@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n\n];

my $page	= RDF::Trine::Node::Resource->new('http://kasei.us/');
my $g		= RDF::Trine::Node::Blank->new('greg');

my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
# my $st0_p	= q[_:greg rdf:type foaf:Person];

my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
# my $st1_p	= q[_:greg foaf:name "Greg"];

my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, $page );
# my $st2_p	= q[_:greg foaf:homepage <http://kasei.us/>];

my $st3		= RDF::Trine::Statement->new( $page, $rdf->type, $foaf->Document );
# my $st3_p	= q[<http://kasei.us/> rdf:type foaf:Document];

{
	my $sink	= RDF::Trine::Serializer::StringSink->new();
	my $log		= RDF::Trine::Exporter::RDFPatch->new( sink => $sink, namespaces => { rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', foaf => 'http://xmlns.com/foaf/0.1/' } );
	my $model	= RDF::Trine::Model->new();
	$model->logger( $log );
	
	$model->add_statement( $st0 );
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n] );
	
	$log->comment("foo");
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n# foo\n] );
	
	$model->add_statement( $st1 );
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n# foo\nA R foaf:name "Greg" .\n] );

	$model->add_statement( $st3 );
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n# foo\nA R foaf:name "Greg" .\nA <http://kasei.us/> rdf:type foaf:Document .\n] );
	
	$model->remove_statement( $st0 );
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n# foo\nA R foaf:name "Greg" .\nA <http://kasei.us/> rdf:type foaf:Document .\nD _:greg R foaf:Person .\n] );
	
	$log->comment("multi-line\ncomment");
	is( $sink->string, qq[${HEADER}A _:greg rdf:type foaf:Person .\n# foo\nA R foaf:name "Greg" .\nA <http://kasei.us/> rdf:type foaf:Document .\nD _:greg R foaf:Person .\n# multi-line\n# comment\n] );
}

done_testing();
