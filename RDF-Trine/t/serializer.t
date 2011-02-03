use Test::More tests => 37;
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
);

my %type_expect	= (
	'nquads'	=> [qw(text/x-nquads)],
	'ntriples'	=> [qw(text/plain)],
	'ntriples-canonical'	=> [],
	'rdfjson'	=> [qw(application/json application/x-rdf+json)],
	'rdfxml'	=> [qw(application/rdf+xml)],
	'turtle'	=> [qw(application/turtle application/x-turtle text/turtle)],
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
	print "# empty Accept header\n";
	my ($sname, $etype)	= ();
	my $h	= new HTTP::Headers;
	$h->header(Accept => "");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h );
	like( $type, qr'^(text|application)/turtle$', "expected media type" );
	isa_ok( $s, "RDF::Trine::Serializer::Turtle", "HTTP negotiated empty accept header to proper serializer" );
}

