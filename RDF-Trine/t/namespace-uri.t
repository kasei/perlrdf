use Test::More tests => 4;

BEGIN {
use_ok( 'RDF::Trine::Namespace' );
}
use RDF::Trine;

my $foaf	= RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
isa_ok( $foaf, 'RDF::Trine::Namespace' );

my $uri		= $foaf->homepage;
isa_ok( $uri, 'RDF::Trine::Node' );

is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage' );
