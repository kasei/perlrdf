#!/usr/bin/perl
use strict;
use warnings;

use Config;
use URI::file;
use Test::More;
use Data::Dumper;

use RDF::Query;
use RDF::Query::Util;
use RDF::Query::Algebra;
use RDF::Query::Federate;
use RDF::Query::Error qw(:try);
use RDF::Query::ServiceDescription;

use RDF::Trine::Parser;
use RDF::Trine::Namespace qw(rdf foaf);

use lib qw(. t);
BEGIN { require "models.pl"; }

my $eval_tests		= 3;
my $rewrite_tests	= 2;
my $run_eval_tests	= 0;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.thresholdunion          = TRACE, Screen
# #	log4perl.category.rdf.query.servicedescription           = DEBUG, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $quit_sig		= 1;
my @sigs	= split(' ', $Config{sig_name});
foreach my $i (0 .. $#sigs) {
	if ($sigs[$i] eq 'QUIT') {
		$quit_sig	= $i;
		last;
	}
}
my %named	= map { $_ => File::Spec->rel2abs("data/federation_data/$_") } qw(alice.rdf bob.rdf);
my %models	= map { $_ => RDF::Query::Util::make_model( $named{$_} ) } (keys %named);


eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
}

eval { require RDF::Endpoint::Server };
if ($@) {
	plan tests => $rewrite_tests;
} else {
	$run_eval_tests	= 1;
	plan tests => ($eval_tests + $rewrite_tests);
}

################################################################################

run_tests();

################################################################################

sub run_tests {
	simple_optimistic_bgp_rewriting_test();
	simple_optimistic_bgp_rewriting_test_with_threshold_time();
	
	if ($run_eval_tests) {
		simple_optimistic_bgp_rewriting_execution_test();
	}
}

sub simple_optimistic_bgp_rewriting_test {
	### in this test, two services are used, both of which support the two triple patterns.
	### we're expecting the optimistic QEP to send the whole 2-triple BGP to each service
	### as a whole, and then fall back on joining the two triple patterns locally.
	
	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows)] );
	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows)] );
	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1 } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?p ?knows WHERE {
			?p foaf:knows ?knows .
			?knows a foaf:Person .
		}
END
	$query->add_service( $alice_sd );
	$query->add_service( $bob_sd );
	my ($plan, $ctx)	= $query->prepare();
	my $sse	= $plan->sse({}, '  ');
	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan' );
		(project (p knows) (threshold-union 0
			  (service <http://127.0.0.1:8891/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
			  (service <http://127.0.0.1:8889/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
			  (bind-join (triple ?knows <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>) (triple ?p <http://xmlns.com/foaf/0.1/knows> ?knows))))
END
	
	### If we were to start an RDF::Endpoint server on the appropriate ports, this should work:
# 	my $iter	= $query->execute_plan( $plan, $ctx );
# 	while (my $row = $iter->next) {
# 		print "$row\n";
# 	}
}

sub simple_optimistic_bgp_rewriting_test_with_threshold_time {
	### this test is the same as simple_optimistic_bgp_rewriting_test() above,
	### but we use a 'optimistic_threshold_time' flag in the constructor, which
	### should come back out in the sse serialization of the thresholdtime QEP.
	
	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows)] );
	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows)] );
	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1, optimistic_threshold_time => 3 } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?p ?knows WHERE {
			?p foaf:knows ?knows .
			?knows a foaf:Person .
		}
END
	$query->add_service( $alice_sd );
	$query->add_service( $bob_sd );
	my ($plan, $ctx)	= $query->prepare();
	my $sse	= $plan->sse({}, '  ');
	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan' );
		(project (p knows) (threshold-union 3
			  (service <http://127.0.0.1:8891/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
			  (service <http://127.0.0.1:8889/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
			  (bind-join (triple ?knows <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>) (triple ?p <http://xmlns.com/foaf/0.1/knows> ?knows))))
END
}

sub simple_optimistic_bgp_rewriting_execution_test {
	my %ports		= qw(alice.rdf 8889 bob.rdf 8891);
	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows foaf:name)] );
	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows foaf:name)] );
	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1, optimistic_threshold_time => 0.0001 } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?p ?name WHERE {
			?p foaf:knows ?knows ; foaf:name ?name.
		}
END
	$query->add_service( $alice_sd );
	$query->add_service( $bob_sd );
	my ($plan, $ctx)	= $query->prepare();
	
	my %pids;
	while (my($name, $model) = each(%models)) {
		my $pid	= start_endpoint_for_service( $ports{ $name }, $model );
		$pids{ $name }	= $pid;
	}
	
	my $iter	= $query->execute_plan( $plan, $ctx );
	
	my %names;
	my %origins;
	my $counter	= 0;
	while (my $row = $iter->next) {
		my $orig	= $row->label('origin');
		foreach my $o (@$orig) {
			$origins{ $o }++;
		}
		$counter++;
		$names{ $row->{name}->literal_value }++;
	}
	
	is( $counter, 3, 'expected result count with duplicates from optimistic execution' );
	
	# we expect to find:
	#	- one result with name=Bob from the optimistic BGP sent to bob's server on port 8891
	#	- zero results from alice's server on port 8889
	#	- two results from the local join that merges data from both servers, one with name=Alice, and one with name=Bob
	is_deeply( \%names, { Bob => 2, Alice => 1 }, 'expected duplicate result counts per result' );
	is_deeply( \%origins, { 'http://127.0.0.1:8889/sparql' => 1, 'http://127.0.0.1:8891/sparql' => 2 }, 'expected originating endpoint distribution' );
	
	while (my($name, $pid) = each(%pids)) {
		kill_endpoint( $pid, $quit_sig );
	}
	sleep 1;
}

sub start_endpoint_for_service {
	my $req_port	= shift;
	my $model		= shift;
	my ($pid, $port)	= RDF::Query::Util::start_endpoint( $model, $req_port++, '../RDF-Endpoint/include' );
	return $pid;
}

sub kill_endpoint {
	my $pid			= shift;
	my $quit_sig	= shift;
	my $sent		= kill( $quit_sig, $pid );
}

sub local_sd {
	my $name		= shift;
	my $port		= shift;
	my $base		= shift;
	my $size		= shift;
	my $preds		= shift || [];
	my $pred_rdf	= join("\n\t", map { "sd:capability [ sd:predicate $_ ] ;" } @$preds);
	my $rdf			= sprintf( <<'END', $name, $port, $size, $pred_rdf );
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix sd: <http://darq.sf.net/dose/0.1#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix saddle: <http://www.w3.org/2005/03/saddle/#> .
@prefix sparql: <http://kasei.us/2008/04/sparql#> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix exif: <http://www.kanzaki.com/ns/exif#> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix dcterms: <http://purl.org/dc/terms/> .

# definition of an endpoint
[] a sd:Service ;
	rdfs:label "SPARQL Endpoint for data from %s" ;
	sd:url <http://127.0.0.1:%d/sparql> ;
	sd:totalTriples %d ;
	%s
	.
END
	my $store	= RDF::Trine::Store::DBI->temporary_store();
	my $model	= RDF::Trine::Model->new( $store );
	my $parser	= RDF::Trine::Parser->new('turtle');
	$parser->parse_into_model( $base, $rdf, $model );
	return RDF::Query::ServiceDescription->new_with_model( $model );
}


sub _CLEAN_WS {
	my $string	= shift;
	$string		=~ s/^\s+//;
	chomp($string);
	for ($string) {
		s/\s+/ /g;
		1 while s/[)]\s+[)]/))/g;
	}
	return $string;
}
