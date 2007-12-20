use Test::More tests => 4;

BEGIN {
use_ok( 'RDF::Trice::Namespace' );
}

my $foaf	= RDF::Trice::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
isa_ok( $foaf, 'RDF::Trice::Namespace' );

my $uri		= $foaf->homepage;
isa_ok( $uri, 'RDF::Trice::Node' );

is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage' );
