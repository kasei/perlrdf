use Test::More tests => 30;
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
	'nquads'	=> [],
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

throws_ok {
	my $h	= new HTTP::Headers;
	$h->header(Accept => "image/jpeg");
	my $s	= RDF::Trine::Serializer->negotiate( request_headers => $h );
} 'RDF::Trine::Error::SerializationError', 'HTTP negotiated serialization throws on unknown media type';

{
	print "# empty Accept header\n";
	my ($sname, $etype)	= ();
	my $h	= new HTTP::Headers;
	$h->header(Accept => "");
	my ($type, $s)	= RDF::Trine::Serializer->negotiate( request_headers => $h );
	like( $type, qr'^(text|application)/turtle$', "expected media type" );
	isa_ok( $s, "RDF::Trine::Serializer::Turtle", "HTTP negotiated empty accept header to proper serializer" );
}

