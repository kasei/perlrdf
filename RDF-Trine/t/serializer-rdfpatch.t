use Test::More;
BEGIN { use_ok('RDF::Trine::Serializer::RDFPatch') };

use strict;
use warnings;

use RDF::Trine;
use RDF::Trine::Parser;

my $store	= RDF::Trine::Store->temporary_store();
my $model	= RDF::Trine::Model->new( $store );

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $page	= RDF::Trine::Node::Resource->new('http://kasei.us/');
my $g		= RDF::Trine::Node::Blank->new('greg');
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, $page );
my $st3		= RDF::Trine::Statement->new( $page, $rdf->type, $foaf->Document );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3);

{
	my $serializer	= RDF::Trine::Serializer::RDFPatch->new();
	my $iter		= RDF::Trine::Iterator->new([$st0, $st1, $st2, $st3]);
	my $string		= $serializer->serialize_iterator_to_string( $iter );
	is( $string, <<"END", 'serialize_iterator_to_string' );
A _:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
A R <http://xmlns.com/foaf/0.1/name> "Greg" .
A R <http://xmlns.com/foaf/0.1/homepage> <http://kasei.us/> .
A <http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
END
}

{

	my $serializer	= RDF::Trine::Serializer::RDFPatch->new( namespaces => { rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', foaf => 'http://xmlns.com/foaf/0.1/' } );
	my $iter		= RDF::Trine::Iterator->new([$st0, $st1, $st2, $st3]);
	my $string		= $serializer->serialize_iterator_to_string( $iter );
	is( $string, <<'END', 'serialize_iterator_to_string with namespaces' );
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

A _:greg rdf:type foaf:Person .
A R foaf:name "Greg" .
A R foaf:homepage <http://kasei.us/> .
A <http://kasei.us/> rdf:type foaf:Document .
END
}

done_testing();
