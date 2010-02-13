use Test::More tests => 7;
use Test::Exception;

use strict;
use warnings;
use File::Spec;

use RDF::Trine qw(iri);
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Serializer;

throws_ok { RDF::Trine::Serializer->new('foobar') } 'RDF::Trine::Error::SerializationError', "RDF::Trine::Serializer constructor throws on unrecognized serializer name";

my %expect	= (
	'nquads'	=> 'RDF::Trine::Serializer::NQuads',
	'ntriples'	=> 'RDF::Trine::Serializer::NTriples',
	'ntriples-canonical'	=> 'RDF::Trine::Serializer::NTriples::Canonical',
	'rdfjson'	=> 'RDF::Trine::Serializer::RDFJSON',
	'rdfxml'	=> 'RDF::Trine::Serializer::RDFXML',
	'turtle'	=> 'RDF::Trine::Serializer::Turtle',
);

while (my($k,$v) = each(%expect)) {
	my $p	= RDF::Trine::Serializer->new( $k );
	isa_ok( $p, $v );
}
