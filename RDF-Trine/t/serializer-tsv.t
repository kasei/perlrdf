#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 3;

use Data::Dumper;
use RDF::Trine qw(iri literal blank);
use RDF::Trine::Iterator;
use RDF::Trine::Namespace qw(rdf xsd foaf);
use RDF::Trine::Statement;
use RDF::Trine::Serializer::TSV;

my $p1		= RDF::Trine::Node::Resource->new('http://example.org/alice');
my $p2		= RDF::Trine::Node::Resource->new('http://example.org/eve');
my $p3		= RDF::Trine::Node::Resource->new('http://example.org/bob');
my $type	= $rdf->type;
my $person	= $foaf->Person;

my $s		= RDF::Trine::Serializer::TSV->new();

{
	my $st1		= RDF::Trine::Statement->new( $p1, $type, $person );
	my $st2		= RDF::Trine::Statement->new( $p2, $type, $person );
	my $st3		= RDF::Trine::Statement->new( $p3, $type, $person );
	my $iter	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3 ] );
	my $string	= $s->serialize_iterator_to_string( $iter );
	is( $string, <<"END", 'tsv serialization' );
<http://example.org/alice>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
<http://example.org/bob>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
END
}

{
	my $st1		= RDF::Trine::Statement->new( $p2, $rdf->type, $foaf->Person );
	my $st2		= RDF::Trine::Statement->new( $p2, $foaf->name, literal('Eve', 'en') );
	my $st3		= RDF::Trine::Statement->new( $p2, $rdf->value, literal('123', undef, $xsd->integer) );
	my $st4		= RDF::Trine::Statement->new( $p2, $rdf->value, blank('foo') );
	my $iter	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3, $st4 ] );
	my $string	= $s->serialize_iterator_to_string( $iter );
	is( $string, <<'END', 'tsv serialization' );
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
<http://example.org/eve>	<http://xmlns.com/foaf/0.1/name>	"Eve"@en
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	"123"^^<http://www.w3.org/2001/XMLSchema#integer>
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	_:foo
END
}

{
	my $st1		= RDF::Trine::Statement->new( $p2, $rdf->type, $foaf->Person );
	my $st2		= RDF::Trine::Statement->new( $p2, $foaf->name, literal('Eve', 'en') );
	my $st3		= RDF::Trine::Statement->new( $p2, $rdf->value, literal('123', undef, $xsd->integer) );
	my $st4		= RDF::Trine::Statement->new( $p2, $rdf->value, blank('foo') );
	my $iter	= RDF::Trine::Iterator::Graph->new( [ $st1, $st2, $st3, $st4 ] );
	my $io		= $s->serialize_iterator_to_io( $iter );
	my $string	= join('', <$io>);
	is( $string, <<'END', 'serialize_iterator_to_io tsv serialization' );
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
<http://example.org/eve>	<http://xmlns.com/foaf/0.1/name>	"Eve"@en
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	"123"^^<http://www.w3.org/2001/XMLSchema#integer>
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	_:foo
END
}
