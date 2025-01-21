#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;

use Test::More;
plan skip_all => "QUERY FEDERATION isn't implemented";

# use RDF::Trine::Namespace qw(rdf foaf);
# my $xsd		= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');
# my $dcterms	= RDF::Trine::Namespace->new('http://purl.org/dc/terms/');
# 
# use lib qw(. t);
# BEGIN { require "models.pl"; }
# 
# use Test::More;
# 
# my $tests	= 22;
# my $network_tests	= $ENV{RDFQUERY_NETWORK_TESTS} || 0;
# if (not exists $ENV{RDFQUERY_DEV_TESTS}) {
# 	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
# 	return;
# } else {
# 	plan tests => $tests;
# }
# 
# use_ok( 'RDF::Query::Federate' );
# use_ok( 'RDF::Query::ServiceDescription' );
# 
# ################################################################################
# # Log::Log4perl::init( \q[
# # 	log4perl.category.rdf.query.servicedescription	= DEBUG, Screen
# # 	log4perl.category.rdf.query.plan.service		= DEBUG, Screen
# # 	log4perl.appender.Screen						= Log::Log4perl::Appender::Screen
# # 	log4perl.appender.Screen.stderr					= 0
# # 	log4perl.appender.Screen.layout					= Log::Log4perl::Layout::SimpleLayout
# # ] );
# ################################################################################
# 
# my $uri	= URI::file->new_abs( 'data/service.ttl' );
# my $sd	= RDF::Query::ServiceDescription->new_from_uri( $uri );
# isa_ok( $sd, 'RDF::Query::ServiceDescription' );
# 
# {
# 	is( $sd->label, 'DBpedia', 'expected endpoint label' );
# 	is( $sd->url, 'http://dbpedia.org/sparql', 'expected endpoint uri' );
# 	is( $sd->size, 58_787_090, 'expected triple size');
# 	is( $sd->definitive, 1, 'expected definitive flag');
# 	
# 	my $o		= RDF::Query::Node::Variable->new('object');
# 	my $expect_p	= {
# 					$rdf->type->uri_value => {
# 							pred				=> RDF::Query::Node::Resource->new( $rdf->type->uri_value ),
# 							sofilter			=> RDF::Query::Expression::Function->new('sparql:regex', RDF::Query::Expression::Function->new('sparql:str', $o), RDF::Query::Node::Literal->new('http://xmlns.com/foaf/0.1/Person')),
# 							size				=> RDF::Query::Node::Literal->new('3683409', undef, $xsd->integer->uri_value),
# 						},
# 					$foaf->name->uri_value => {
# 							pred				=> RDF::Query::Node::Resource->new( $foaf->name->uri_value ),
# 							sofilter			=> undef,
# 							size				=> RDF::Query::Node::Literal->new('18000', undef, $xsd->integer->uri_value),
# 							object_selectivity	=> RDF::Query::Node::Literal->new('0.02', undef, $xsd->double->uri_value),
# 						},
# 					$foaf->mbox->uri_value => {
# 							pred				=> RDF::Query::Node::Resource->new( $foaf->mbox->uri_value ),
# 							sofilter			=> undef,
# 							size				=> RDF::Query::Node::Literal->new('18000', undef, $xsd->integer->uri_value),
# 							object_selectivity	=> RDF::Query::Node::Literal->new('5.5E-5', undef, $xsd->double->uri_value),
# 						},
# 					$dcterms->spatial->uri_value => {
# 							pred				=> RDF::Query::Node::Resource->new( $dcterms->spatial->uri_value ),
# 						},
# 				};
# 	my $cap	= $sd->capabilities;
# 	foreach my $data (grep {exists $_->{pred}} @$cap) {
# 		my $p	= $data->{pred}->uri_value;
# 		my $e	= delete $expect_p->{ $p };
# 		isa_ok( $e, 'HASH' );
# 		is_deeply( $data, $e, "capability for $p" );
# 	}
# 	is_deeply( $expect_p, {}, 'seen all expected predicate-based capabilities' );
# 	
# 	my $expect_t	= {
# 					'http://kasei.us/2008/04/sparql#any_triple'	=> 1,
# 				};
# 	foreach my $data (grep {exists $_->{type}} @$cap) {
# 		my $type	= $data->{type}->uri_value;
# 		my $ok		= delete( $expect_t->{ $type } );
# 		ok( $ok, "expected type-capability: $type" );
# 	}
# 	is_deeply( $expect_t, {}, 'seen all expected type-based capabilities' );
# }
# 
# SKIP: {
# 	skip "set RDFQUERY_NETWORK_TESTS to run these tests", 3 unless ($network_tests);
# 	my $query	= RDF::Query::Federate->new( <<"END" );
# 		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 		SELECT ?name
# 		WHERE { <http://dbpedia.org/resource/Alan_Turing> foaf:name ?name . FILTER( LANG(?name) = "en" ) }
# END
# 	$query->add_computed_statement_generator( $sd->computed_statement_generator );
# 	my $iter	= $query->execute;
# 	my $count	= 0;
# 	while (my $row = $iter->next) {
# 		isa_ok( $row, 'HASH' );
# 		my $name	= $row->{name};
# 		like( $name->literal_value, qr"^Alan.*Turing$", 'execution: expected foaf:name in federation description' );
# 		$count++;
# 		last;
# 	}
# 	is( $count, 1, 'got results from dbpedia' );
# }
# 
# SKIP: {
# 	skip "set RDFQUERY_NETWORK_TESTS to run these tests", 1 unless ($network_tests);
# 	my $query	= RDF::Query::Federate->new( <<"END" );
# 		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 		PREFIX dbp: <http://dbpedia.org/property/>
# 		SELECT ?job
# 		WHERE { <http://dbpedia.org/resource/Alan_Turing> dbp:occupation ?job }
# END
# 	$query->add_computed_statement_generator( $sd->computed_statement_generator );
# 	my $iter	= $query->execute;
# 	my $count	= 0;
# 	while (my $row = $iter->next) {
# 		$count++;
# 	}
# 	is( $count, 0, 'execution: expected dbp:occupation not in federation description' ); 
# }
