use Test::More tests => 14;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use Data::Dumper;
use utf8;
binmode( \*STDOUT, ':utf8' );
binmode( \*STDERR, ':utf8' );

use RDF::Trine qw(iri blank literal);
use RDF::Trine::Parser;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.trine.model          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $parser	= RDF::Trine::Parser::TriG->new();
isa_ok( $parser, 'RDF::Trine::Parser::TriG' );

{
	my $model = RDF::Trine::Model->temporary_model;
	my $trig	= <<'END';
# TriG Example Document 2
@prefix ex: <http://www.example.org/vocabulary#> .
@prefix : <http://www.example.org/exampleDocument#> .
:G1 = { :Monica a ex:Person ;
                 ex:name "Monica Murphy" ;      
                 ex:homepage <http://www.monicamurphy.org> ;
                 ex:email <mailto:monica@monicamurphy.org> ;
                 ex:hasSkill ex:Management ,
                             ex:Programming . } .
END
	$parser->parse_into_model(undef, $trig, $model);
	
	is( $model->size, 6, 'expected model (triple) size after nquads parse' );
	is( $model->count_statements(undef, undef, undef, undef), 6, 'expected 6 count ffff' );
	is( $model->count_statements(iri('http://www.example.org/exampleDocument#Monica'), undef, undef, undef), 6, 'expected 2 count bfff' );
	is( $model->count_statements(iri('b')), 0, 'expected 0 count bff' );
	is( $model->count_statements(iri('b'), undef, undef, undef), 0, 'expected 0 count bfff' );
	is( $model->count_statements(undef, iri('http://www.example.org/vocabulary#hasSkill')), 2, 'expected 2 count fbf' );
	is( $model->count_statements(undef, iri('http://www.example.org/vocabulary#hasSkill'), undef, undef), 2, 'expected 2 count fbff' );
	is( $model->count_statements(undef, undef, undef, iri('http://www.example.org/exampleDocument#G1')), 6, 'expected 6 count fffb' );
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $trig	= <<'END';
# TriG Example Document 1
# This document encodes three graphs.
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix swp: <http://www.w3.org/2004/03/trix/swp-1/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix ex: <http://www.example.org/vocabulary#> .
@prefix : <http://www.example.org/exampleDocument#> .
:G1 { :Monica ex:name "Monica Murphy" .      
      :Monica ex:homepage <http://www.monicamurphy.org> .
      :Monica ex:email <mailto:monica@monicamurphy.org> .
      :Monica ex:hasSkill ex:Management }

:G2 { :Monica rdf:type ex:Person .
      :Monica ex:hasSkill ex:Programming }

:G3 { :G1 swp:assertedBy _:w1 .
      _:w1 swp:authority :Chris .
      _:w1 dc:date "2003-10-02"^^xsd:date .   
      :G2 swp:quotedBy _:w2 .
      :G3 swp:assertedBy _:w2 .
      _:w2 dc:date "2003-09-03"^^xsd:date .
      _:w2 swp:authority :Chris .
      :Chris rdf:type ex:Person .  
      :Chris ex:email <mailto:chris@bizer.de> }
END
	$parser->parse_into_model(undef, $trig, $model);
	
	{
		my $iter	= $model->get_contexts;
		my %expect	= (
			'<http://www.example.org/exampleDocument#G1>'	=> 1,
			'<http://www.example.org/exampleDocument#G2>'	=> 1,
			'<http://www.example.org/exampleDocument#G3>'	=> 1,
		);
		my %got;
		while (my $c = $iter->next) {
			$got{ $c->as_string }++;
		}
		is_deeply( \%got, \%expect, 'expected graph names' );
	}
	
	{
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my %expect	= (
			'<http://www.example.org/exampleDocument#G1>'	=> 4,
			'<http://www.example.org/exampleDocument#G2>'	=> 2,
			'<http://www.example.org/exampleDocument#G3>'	=> 9,
		);
		my %got;
		while (my $st = $iter->next) {
			$got{ $st->context->as_string }++;
		}
		is_deeply( \%got, \%expect, 'expected statement counts per graph name' );
	}
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $trig	= <<'END';
# TriG Example Document 3
# This document contains a default graph and two named graphs.
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
# default graph
    { 
      <http://example.org/bob> dc:publisher "Bob" . 
      <http://example.org/alice> dc:publisher "Alice" .
    }

<http://example.org/bob> 
    { 
       _:a foaf:name "Bob" . 
       _:a foaf:mbox <mailto:bob@oldcorp.example.org> .
    }
 
<http://example.org/alice>
    { 
       _:a foaf:name "Alice" . 
       _:a foaf:mbox <mailto:alice@work.example.org> .
    }
END
	$parser->parse_into_model(undef, $trig, $model);
	
	{
		my $iter	= $model->get_contexts;
		my %expect	= (
			'<http://example.org/bob>'	=> 1,
			'<http://example.org/alice>'	=> 1,
		);
		my %got;
		while (my $c = $iter->next) {
			$got{ $c->as_string }++;
		}
		is_deeply( \%got, \%expect, 'expected graph names' );
	}
	
	{
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my %expect	= (
			'(nil)'	=> 2,
			'<http://example.org/bob>'	=> 2,
			'<http://example.org/alice>'	=> 2,
		);
		my %got;
		while (my $st = $iter->next) {
			$got{ $st->context->as_string }++;
		}
		is_deeply( \%got, \%expect, 'expected statement counts per graph name' );
	}
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $trig	= <<'END';
# TriG Example Document 4
# This document contains a default graph and one named graphs with non-ASCII chars.
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://www.example.org/vocabulary#> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
# default graph
    { 
      <http://example.org/bob> dc:publisher "Bob" . 
      <http://example.org/alice> dc:publisher "Alice" .
    }

<http://example.org/bob> 
    { 
       _:a foaf:name "Bob" . 
       _:a ex:likes "Blåbærsyltetøy"@no .
    }

END
	$parser->parse_into_model(undef, $trig, $model);
	my $iter = $model->get_statements( undef,
					   RDF::Trine::Node::Resource->new('http://www.example.org/vocabulary#likes'),
					   undef, undef );
	my $st = $iter->next;
	is($st->object->literal_value, 'Blåbærsyltetøy', "Finding UTF-8 string");
}

