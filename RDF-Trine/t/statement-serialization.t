use Test::More tests => 4;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use_ok 'RDF::Trine::Statement';
use_ok 'RDF::Trine::Statement::Quad';
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
	is( $st->sse, '(triple <http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document>)' );
}

{
	my $st		= RDF::Trine::Statement::Quad->new( $kasei, $dc->description, $desc, $myfoaf );
	is( $st->sse, '(quad <http://kasei.us/> <http://purl.org/dc/elements/1.1/description> "my homepage" <http://kasei.us/about/foaf.xrdf>)' );
}
