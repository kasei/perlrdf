use Test::More tests => 5;

use RDF::Trine;
use RDF::Trine::Namespace qw(FOAF DC rdf);

isa_ok( $FOAF, 'RDF::Trine::Namespace' );

my $uri		= $FOAF->homepage;
isa_ok( $uri, 'RDF::Trine::Node' );

is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage', 'foaf:homepage' );
is( $DC->title->uri_value, 'http://purl.org/dc/elements/1.1/title', 'dc:title' );
is( $rdf->type->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'rdf:type (lowercased known namespace)' );
