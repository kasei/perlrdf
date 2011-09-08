use Test::More tests => 47;
use Test::Exception;

use strict;
use warnings;
use File::Spec;
use HTTP::Headers;

use RDF::Trine qw(iri);
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Serializer;

throws_ok { RDF::Trine::Serializer->new('foobar') } 'RDF::Trine::Error::SerializationError', "RDF::Trine::Serializer constructor throws on unrecognized serializer name";

my %name_expect	= (
	'nquads'	=> 'RDF::Trine::Serializer::NQuads',
	'ntriples'	=> 'RDF::Trine::Serializer::NTriples',
	'ntriples-canonical'	=> 'RDF::Trine::Serializer::NTriples::Canonical',
	'rdfjson'	=> 'RDF::Trine::Serializer::RDFJSON',
	'rdfxml'	=> 'RDF::Trine::Serializer::RDFXML',
	'turtle'	=> 'RDF::Trine::Serializer::Turtle',
	'sparqlxml'	=> 'RDF::Trine::Serializer::SPARQLXML',
	'sparqljson'	=> 'RDF::Trine::Serializer::SPARQLJSON',
);

my %type_expect	= (
	'nquads'	=> [qw(text/x-nquads)],
	'ntriples'	=> [qw(text/plain)],
	'ntriples-canonical'	=> [],
	'rdfjson'	=> [qw(application/json application/x-rdf+json)],
	'rdfxml'	=> [qw(application/rdf+xml)],
	'turtle'	=> [qw(application/turtle application/x-turtle text/rdf+n3 text/turtle)],
	'sparqlxml'	=> [qw(application/sparql-results+xml)],
	'sparqljson'	=> [qw(application/sparql-results+json)],
);

while (my($k,$v) = each(%name_expect)) {
	my $p	= RDF::Trine::Serializer->new( $k );
	isa_ok( $p, $v );
	my @types	= $p->media_types;
	is_deeply( \@types, $type_expect{ $k }, "expected media types for $k" );
}

{
	my %negotiate_expect	= (
		"text/plain"	=> ['NTriples', 'text/plain'],
		"application/rdf+xml"	=> ['RDFXML', 'application/rdf+xml'],
		"image/jpeg;q=1,application/rdf+xml;q=0.5"	=> ['RDFXML', 'application/rdf+xml'],
		"application/rdf+xml;q=1,text/plain"	=> ['RDFXML', 'application/rdf+xml'],
		"application/rdf+xml;q=0,text/plain;q=1"	=> ['NTriples', 'text/plain'],
		"application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml"	=> ['Turtle', 'text/turtle'],
		"application/x-turtle;q=1,text/turtle;q=0.7"	=> ['Turtle', 'application/x-turtle'],
		"application/sparql-results+xml;q=0.5,text/foobar;q=1.0"	=> ['SPARQLXML', 'application/sparql-results+xml'],
		"application/sparql-results+xml;q=0.5,application/sparql-results+json;q=1.0"	=> ['SPARQLJSON', 'application/sparql-results+json'],
	);
	
	while (my ($accept,$data) = each(%negotiate_expect)) {
		my ($sname, $etype)	= @$data;
		my $h	= new HTTP::Headers;
		$h->header(Accept => $accept);
		my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h );
		is( $type, $etype, "expected media type for $sname serialization is $etype" );
		unless (isa_ok( $s, "RDF::Trine::Serializer::$sname", "HTTP negotiated $sname serializer" )) {
			warn "# $accept";
		}
	}
}

{
	my $h = new HTTP::Headers;
	$h->header(Accept=>"application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,*/*;0.5");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h );
	ok ( $type, 'choose some serializer for Accept: */*' );
}

{
	my $h = new HTTP::Headers;
	$h->header(Accept=>"application/rdf+xml;q=1,text/turtle;q=0.7");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h, restrict => [ 'turtle' ] );
	is ( $type, 'text/turtle', 'choose less wanted serializer with restrict option' );
}

{
	my $h = new HTTP::Headers;
	$h->header(Accept=>"application/xhtml+xml;q=0.8,application/rdf+xml;q=0.9,text/turtle;q=0.7");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate(
		request_headers => $h,
		restrict => [ 'turtle' ],
		extend => {
			'text/html'	=> 'html',
			'application/xhtml+xml' => 'xhtml',
		},
	);
	is( $type, 'application/xhtml+xml', "negotiation with both 'restrict' restriction and 'extend' custom type" );
	is( $s, 'xhtml', 'negotiation custom type thunk' );
}

{
	my $h = new HTTP::Headers;
	$h->header(Accept=>"application/rdf+xml;q=0.9,text/turtle;q=0.7");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate(
		request_headers => $h,
		extend => {
			'application/rdf+xml'	=> 'rdfxml',
		},
	);
	is($type, 'application/rdf+xml', 'extended negotiation with media type collision');
	is($s, 'rdfxml', 'extended negotiation with media type collision');
}


my %negotiate_fail	= (
	"image/jpeg" =>	undef,
	"application/rdf+xml" => ['turtle','rdfjson']
);

while (my ($accept,$restrict) = each(%negotiate_fail)) {
	throws_ok {
		my $h = new HTTP::Headers;
		$h->header(Accept => $accept);
		my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h, restrict => $restrict );
	} 'RDF::Trine::Error::SerializationError', "HTTP negotiated serialization throws on unknown/unwanted media type $accept";
}

{
	my ($sname, $etype)	= ();
	my $h	= new HTTP::Headers;
	$h->header(Accept => "");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h );
	like( $type, qr'^(text|application)/turtle$', "expected media type with empty accept header" );
	isa_ok( $s, "RDF::Trine::Serializer::Turtle", "HTTP negotiated empty accept header to proper serializer" );
}

{
	my $rdf	= <<'END';
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix : <http://example.com/> .

:me a foaf:Person .
END

	my $map		= RDF::Trine::NamespaceMap->new();
	my $model	= RDF::Trine::Model->new();
	my $parser	= RDF::Trine::Parser->new( 'turtle', namespaces => $map );
	$parser->parse_into_model( 'http://base/', $rdf, $model );
	my $s		= RDF::Trine::Serializer->new( 'rdfxml', namespaces => $map );
	my $xml		= $s->serialize_model_to_string( $model );
	like( $xml, qr[xmlns="http://example.com/"]sm, 'good XML namespaces using namespacemap from parser' );
	like( $xml, qr[xmlns:foaf="http://xmlns.com/foaf/0.1/"]sm, 'good XML namespaces using namespacemap from parser' );
}
