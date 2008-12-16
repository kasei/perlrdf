#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More;
use Data::Dumper;

use lib qw(. t);
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.parser          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $file	= 'data/foaf.xrdf';
my %named	= map { $_ => URI::file->new_abs( File::Spec->rel2abs("data/named_graphs/$_") ) } qw(alice.rdf bob.rdf meta.rdf repeats1.rdf repeats2.rdf);

eval "use RDF::Query::Model::RDFTrine;";
if ($@) {
	plan skip_all => "RDF::Trine is not available for loading";
	return;
} else {
	plan qw(no_plan); #tests => scalar(@models) * $model_tests + $nomodel_tests;
}

use RDF::Query;
use RDF::Trine::Namespace qw(rdf foaf);

use RDF::Query::Plan;

my ($data)	= grep { $_->{bridge}->isa('RDF::Query::Model::RDFTrine') } test_models_and_classes($file);

################################################################################

if ($data) {
	my $bridge	= $data->{bridge};
	my $model	= $data->{modelobj};
	foreach my $uri (values %named) {
		$bridge->add_uri( "$uri", 1 );
	}
	
	my $context	= RDF::Query::ExecutionContext->new(
					bound		=> {},
					model		=> $bridge,
					model_optimize	=> 1,
				);
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
		my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
		my ($plan)	= RDF::Query::Plan->generate_plans( $bgp, $context );
		isa_ok( $plan, 'RDF::Query::Model::RDFTrine::BasicGraphPattern', 'model-optimized BGP algebra plan' );
		my $count	= 0;
		$plan->execute( $context );
		while (my $row = $plan->next) {
			isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
			$count++;
		}
		$plan->close;
		is( $count, 4, "expected result count for model-optimized BGP (?p a foaf:Person ; foaf:name ?name)" );
	}
} else {
	BAIL_OUT("No bridge object available");
}
