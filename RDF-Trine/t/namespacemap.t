use Test::More tests => 5;

use RDF::Trine;
use RDF::Trine::Namespace qw(rdf);

my $foaf	= RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
my $map		= RDF::Trine::NamespaceMap->new( { foaf => $foaf, rdf => $rdf } );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

my $type	= $map->rdf('type');
isa_ok( $type, 'RDF::Trine::Node::Resource' );
is( $type->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'expected uri for namespace map qname' );

my $ns		= $map->foaf;
isa_ok( $ns, 'RDF::Trine::Namespace' );
my $uri	= $ns->uri_value;
is( $ns->uri_value->uri_value, 'http://xmlns.com/foaf/0.1/', 'expected resource object for namespace from namespace map' );
