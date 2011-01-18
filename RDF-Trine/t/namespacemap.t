use Test::More tests => 14;

use RDF::Trine;
use RDF::Trine::Namespace qw(rdf xsd);

$map		= RDF::Trine::NamespaceMap->new;
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

my $foaf	= RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
my $map		= RDF::Trine::NamespaceMap->new( { foaf => $foaf, rdf => $rdf } );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

$map		= RDF::Trine::NamespaceMap->new( foaf => $foaf, rdf => $rdf, xsd => 'http://www.w3.org/2001/XMLSchema#' );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

my $ns		= $map->xsd;
isa_ok( $ns, 'RDF::Trine::Namespace' );
$map->remove_mapping( 'xsd' );
is( $map->xsd, undef, 'removed namespace' );

$map = RDF::Trine::NamespaceMap->new( { foaf => 'http://xmlns.com/foaf/0.1/' } );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

$map->add_mapping( rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' );

my $type	= $map->rdf('type');
isa_ok( $type, 'RDF::Trine::Node::Resource' );
is( $type->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'expected uri for namespace map qname' );

$ns		= $map->foaf;
isa_ok( $ns, 'RDF::Trine::Namespace' );
my $uri	= $ns->uri_value;
is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/', 'expected resource object for namespace from namespace map' );

$type		= $map->uri('rdf:type');
isa_ok( $type, 'RDF::Trine::Node::Resource' );
is( $type->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'resolving via uri method' );

$uri		= $map->uri('foaf:');
is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/', 'resolving via uri method' );

$uri		= $map->uri('foaf');
isa_ok( $type, 'RDF::Trine::Node::Resource' );

