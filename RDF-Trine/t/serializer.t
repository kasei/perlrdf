use Test::More tests => 14;
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

while (my($k,$v) = each(%name_expect)) {
	my $p	= RDF::Trine::Serializer->new( $k );
	isa_ok( $p, $v );
}


my %negotiate_expect	= (
	"text/plain"	=> 'NTriples',
	"application/rdf+xml"	=> 'RDFXML',
	"image/jpeg;q=1,application/rdf+xml;q=0.5"	=> 'RDFXML',
	"application/rdf+xml;q=1,text/plain"	=> 'RDFXML',
	"application/rdf+xml;q=0,text/plain;q=1"	=> 'NTriples',
	"application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml"	=> 'Turtle',
);

while (my ($accept,$sname) = each(%negotiate_expect)) {
	my $h	= new HTTP::Headers;
	$h->header(Accept => $accept);
	my $s	= RDF::Trine::Serializer->negotiate( request_headers => $h );
	unless (isa_ok( $s, "RDF::Trine::Serializer::$sname", "HTTP negotiated $sname serializer" )) {
		warn "# $accept";
	}
}

throws_ok {
	my $h	= new HTTP::Headers;
	$h->header(Accept => "image/jpeg");
	my $s	= RDF::Trine::Serializer->negotiate( request_headers => $h );
} 'RDF::Trine::Error::SerializationError', 'HTTP negotiated serialization throws on unknown media type';
