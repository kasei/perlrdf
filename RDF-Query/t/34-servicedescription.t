#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;

use RDF::Trine::Namespace qw(rdf foaf);
my $xsd	= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my $tests	= 15;
if (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} elsif (exists $ENV{RDFQUERY_NETWORK_TESTS}) {
	plan tests => $tests;
} else {
	plan skip_all => 'No network. Set RDFQUERY_DEV_TESTS and set RDFQUERY_NETWORK_TESTS to run these tests.';
	return;
}

use_ok( 'RDF::Query::ServiceDescription' );

my $uri		= URI::file->new_abs( 'data/service.ttl' );
my $sd	= RDF::Query::ServiceDescription->new( $uri );
isa_ok( $sd, 'RDF::Query::ServiceDescription' );

{
	is( $sd->label, 'DBpedia', 'expected endpoint label' );
	is( $sd->url, 'http://dbpedia.org/sparql', 'expected endpoint uri' );
	is( $sd->size, 58_787_090, 'expected triple size');
	is( $sd->definitive, 0, 'expected definitive flag');
	
	my $o		= RDF::Query::Node::Variable->new('object');
	my $expect	= {
					$rdf->type->uri_value => {
							pred				=> RDF::Query::Node::Resource->new( $rdf->type->uri_value ),
							sofilter			=> RDF::Query::Expression::Function->new('sparql:regex', RDF::Query::Expression::Function->new('sparql:str', $o), RDF::Query::Node::Literal->new('http://xmlns.com/foaf/0.1/Person')),
							size				=> RDF::Query::Node::Literal->new('3683409', undef, $xsd->integer->uri_value),
						},
					$foaf->name->uri_value => {
							pred				=> RDF::Query::Node::Resource->new( $foaf->name->uri_value ),
							sofilter			=> undef,
							size				=> RDF::Query::Node::Literal->new('18000', undef, $xsd->integer->uri_value),
							object_selectivity	=> RDF::Query::Node::Literal->new('0.02', undef, $xsd->double->uri_value),
						},
					$foaf->mbox->uri_value => {
							pred				=> RDF::Query::Node::Resource->new( $foaf->mbox->uri_value ),
							sofilter			=> undef,
							size				=> RDF::Query::Node::Literal->new('18000', undef, $xsd->integer->uri_value),
							object_selectivity	=> RDF::Query::Node::Literal->new('5.5e-05', undef, $xsd->double->uri_value),
						},
				};
	my $cap	= $sd->capabilities;
	foreach my $data (@$cap) {
		my $p	= $data->{pred}->uri_value;
		my $e	= delete $expect->{ $p };
		isa_ok( $e, 'HASH' );
		is_deeply( $data, $e, "capability for $p" );
	}
}

{
	my $query	= RDF::Query->new( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?name
		WHERE { <http://dbpedia.org/resource/Alan_Turing> foaf:name ?name . FILTER( LANG(?name) = "de" ) }
END
	$query->add_computed_statement_generator( $sd->computed_statement_generator );
	my $iter	= $query->execute;
	while (my $row = $iter->next) {
		isa_ok( $row, 'HASH' );
		my $name	= $row->{name};
		is( $name->literal_value, "Alan Turing", 'execution: expected foaf:name in federation description' );
	}
}

{
	my $query	= RDF::Query->new( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX dbp: <http://dbpedia.org/property/>
		SELECT ?job
		WHERE { <http://dbpedia.org/resource/Alan_Turing> dbp:occupation ?job }
END
	$query->add_computed_statement_generator( $sd->computed_statement_generator );
	my $iter	= $query->execute;
	my $count	= 0;
	while (my $row = $iter->next) {
		$count++;
	}
	is( $count, 0, 'execution: expected dbp:occupation not in federation description' ); 
}
