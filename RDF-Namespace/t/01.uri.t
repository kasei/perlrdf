use Test::More tests => 4;

BEGIN {
use_ok( 'RDF::Namespace' );
}

my $foaf	= RDF::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
isa_ok( $foaf, 'RDF::Namespace' );

my $uri		= $foaf->homepage;
isa_ok( $uri, 'RDF::Query::Node' );

is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage' );
