#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More;

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
?s	?p	?o
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
?s	?p	?o
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
<http://example.org/eve>	<http://xmlns.com/foaf/0.1/name>	"Eve"@en
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	"123"^^<http://www.w3.org/2001/XMLSchema#integer>
<http://example.org/eve>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#value>	_:foo
END
}

{
	my $r1		= RDF::Trine::VariableBindings->new({ foo => literal('Eve', 'en'), bar => $foaf->Person });
	my $r2		= RDF::Trine::VariableBindings->new({ foo => literal('Alice'), bar => $foaf->Agent });
	my $r3		= RDF::Trine::VariableBindings->new({ foo => literal('Bob') });
	my $iter	= RDF::Trine::Iterator::Bindings->new( [ $r1, $r2, $r3 ], [qw(foo bar)] );
	my $string	= $s->serialize_iterator_to_string( $iter );
	is( $string, <<'END', 'tsv serialization' );
?foo	?bar
"Eve"@en	<http://xmlns.com/foaf/0.1/Person>
"Alice"	<http://xmlns.com/foaf/0.1/Agent>
"Bob"	
END
}

{
	my $model	= RDF::Trine::Model->new();
	my $st1		= RDF::Trine::Statement->new( $p1, $type, $person );
	$model->add_statement($st1);
	my $string	= '';
	open(my $fh, '>', \$string);
	$s->serialize_model_to_file($fh, $model);
	is( $string, <<"END", 'tsv serialization: serialize_model_to_file (#155, #156)' );
s	p	o
<http://example.org/alice>	<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>	<http://xmlns.com/foaf/0.1/Person>
END
}

done_testing();
