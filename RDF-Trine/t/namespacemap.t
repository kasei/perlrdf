use Test::More tests => 21;

use strict;
use RDF::Trine;
use RDF::Trine::Namespace qw(rdf xsd);

my $foaf	= RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );

{
	my $map		= RDF::Trine::NamespaceMap->new;
	isa_ok( $map, 'RDF::Trine::NamespaceMap' );
}

{
	my $map		= RDF::Trine::NamespaceMap->new( { foaf => $foaf, rdf => $rdf } );
	isa_ok( $map, 'RDF::Trine::NamespaceMap' );
}

my $map		= RDF::Trine::NamespaceMap->new( { foaf => $foaf, rdf => $rdf, xsd => 'http://www.w3.org/2001/XMLSchema#' } );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );

my $ns		= $map->xsd;
isa_ok( $ns, 'RDF::Trine::Namespace' );
$map->remove_mapping( 'xsd' );
is( $map->xsd, undef, 'removed namespace' );

$map = RDF::Trine::NamespaceMap->new( { foaf => 'http://xmlns.com/foaf/0.1/', '' => 'http://example.org/' } );
isa_ok( $map, 'RDF::Trine::NamespaceMap' );
is ( $map->uri(':foo')->uri_value, 'http://example.org/foo', 'empty prefix' );

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

# abbreviate implicitly checks prefix_for

is($map->abbreviate($map->foaf('Person')), 'foaf:Person', 'abbrev with prefix');

is($map->abbreviate($map->uri(':foo')), ':foo', 'abbrev no prefix ');

is($map->abbreviate('http://derp.net/foobar'), undef, 'abbrev no match');

ok($map->list_prefixes, 'map contains prefixes');
ok($map->list_namespaces, 'map contains namespaces');

{
	my $rdf	= <<'END';
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns="http://example.com/" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="http://example.com/me">
	<rdf:type rdf:resource="http://xmlns.com/foaf/0.1/Person"/>
</rdf:Description>
</rdf:RDF>
END

	my $map		= RDF::Trine::NamespaceMap->new();
	my $model	= RDF::Trine::Model->new();
	my $parser	= RDF::Trine::Parser->new( 'rdfxml', namespaces => $map );
	$parser->parse_into_model( 'http://base/', $rdf, $model );
	my $s		= RDF::Trine::Serializer->new( 'turtle', namespaces => $map );
	my $ttl		= $s->serialize_model_to_string( $model );
	like( $ttl, qr< a foaf:Person>sm, 'namespaces pass through parser to serializer' );
}
