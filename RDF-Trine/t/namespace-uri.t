use Test::More tests => 3;

use RDF::Trine;

my $foaf	= RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
isa_ok( $foaf, 'RDF::Trine::Namespace' );

my $uri		= $foaf->homepage;
ok( $uri->DOES('RDF::Trine::Node::API') );

is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage' );
