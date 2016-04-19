#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
plan skip_all => "QUERY FEDERATION isn't implemented";

# use Config;
# use URI::file;
# use Test::More;
# use Data::Dumper;
# 
# use RDF::Query;
# use RDF::Query::Util;
# use RDF::Query::Algebra;
# use RDF::Query::Federate;
# use RDF::Query::Error qw(:try);
# use RDF::Query::ServiceDescription;
# 
# use RDF::Trine::Parser;
# use RDF::Trine::Namespace qw(rdf foaf);
# 
# use lib qw(. t);
# BEGIN { require "models.pl"; }
# 
# my $eval_tests		= 3;
# my $rewrite_tests	= 4;
# my $run_eval_tests	= 1;
# 
# if (not $ENV{RDFQUERY_DEV_TESTS}) {
# 	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
# 	return;
# }
# 
# plan tests => ($eval_tests + $rewrite_tests);
# 
# my $reason;
# eval { require LWP::Simple };
# if ($@) {
# 	$run_eval_tests	= 0;
# 	$reason			= "LWP::Simple is not available for loading <http://...> URLs";
# }
# 
# eval { require RDF::Endpoint::Server };
# if ($@) {
# 	$run_eval_tests	= 0;
# 	$reason			= "RDF::Endpoint::Server is not available";
# }
# 
# ################################################################################
# # Log::Log4perl::init( \q[
# # #	log4perl.category.rdf.query.federate.plan          = TRACE, Screen
# # 	log4perl.category.rdf.query.plan.thresholdunion          = TRACE, Screen
# # #	log4perl.category.rdf.query.servicedescription           = DEBUG, Screen
# # 	
# # 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# # 	log4perl.appender.Screen.stderr  = 0
# # 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# # ] );
# ################################################################################
# 
# my $quit_sig		= 1;
# my @sigs	= split(' ', $Config{sig_name});
# foreach my $i (0 .. $#sigs) {
# 	if ($sigs[$i] eq 'QUIT') {
# 		$quit_sig	= $i;
# 		last;
# 	}
# }
# my %named	= map { $_ => File::Spec->rel2abs("data/federation_data/$_") } qw(alice.rdf bob.rdf);
# my %models	= map { $_ => RDF::Query::Util::make_model( {}, $named{$_} ) } (keys %named);
# 
# 
# ################################################################################
# 
# run_tests();
# 
# ################################################################################
# 
# sub run_tests {
# 	simple_optimistic_bgp_rewriting_test();
# 	simple_optimistic_bgp_rewriting_test_with_threshold_time();
# 	overlapping_optimistic_bgp_rewriting_test_1();
# 	overlapping_optimistic_bgp_rewriting_test_2();
# 	
# 	SKIP: {
# 		skip $reason, $eval_tests unless ($run_eval_tests);
# 		simple_optimistic_bgp_rewriting_execution_test();
# 	}
# }
# 
# sub simple_optimistic_bgp_rewriting_test {
# 	### in this test, two services are used, both of which support the two triple patterns.
# 	### we're expecting the optimistic QEP to send the whole 2-triple BGP to each service
# 	### as a whole, and then fall back on joining the two triple patterns locally.
# 	
# 	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows)] );
# 	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows)] );
# 	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1 } );
# 		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 		SELECT ?p ?knows WHERE {
# 			?p foaf:knows ?knows .
# 			?knows a foaf:Person .
# 		}
# END
# 	$query->add_service( $alice_sd );
# 	$query->add_service( $bob_sd );
# 	my ($plan, $ctx)	= $query->prepare();
# 	my $sse	= $plan->sse({}, '  ');
# 	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan' );
# (project (p knows) (threshold-union 0
# 	(service <http://127.0.0.1:8889/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p foaf:knows ?knows .\n\t?knows a foaf:Person .\n}")
# 	(service <http://127.0.0.1:8891/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p foaf:knows ?knows .\n\t?knows a foaf:Person .\n}")
# 	(bind-join
# 		(triple ?knows <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>)
# 		(triple ?p <http://xmlns.com/foaf/0.1/knows> ?knows))))
# END
# 	### If we were to start an RDF::Endpoint server on the appropriate ports, this should work:
# # 	my $iter	= $query->execute_plan( $plan, $ctx );
# # 	while (my $row = $iter->next) {
# # 		print "$row\n";
# # 	}
# }
# 
# sub simple_optimistic_bgp_rewriting_test_with_threshold_time {
# 	### this test is the same as simple_optimistic_bgp_rewriting_test() above,
# 	### but we use a 'optimistic_threshold_time' flag in the constructor, which
# 	### should come back out in the sse serialization of the thresholdtime QEP.
# 	
# 	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows)] );
# 	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows)] );
# 	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1, optimistic_threshold_time => 3 } );
# 		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 		SELECT ?p ?knows WHERE {
# 			?p foaf:knows ?knows .
# 			?knows a foaf:Person .
# 		}
# END
# 	$query->add_service( $alice_sd );
# 	$query->add_service( $bob_sd );
# 	my ($plan, $ctx)	= $query->prepare();
# 	my $sse	= $plan->sse({}, '  ');
# 	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan' );
# 		(project (p knows)
# 			(threshold-union 3
# 				(service <http://127.0.0.1:8889/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p foaf:knows ?knows .\n\t?knows a foaf:Person .\n}")
# 				(service <http://127.0.0.1:8891/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p foaf:knows ?knows .\n\t?knows a foaf:Person .\n}")
# 				(bind-join
# 					(triple ?knows <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>)
# 					(triple ?p <http://xmlns.com/foaf/0.1/knows> ?knows))
# 			)
# 		)
# END
# }
# 
# sub overlapping_optimistic_bgp_rewriting_test_1 {
# 	### this test uses four endpoint service descriptions, with overlapping
# 	### coverage of five predicates:
# 	### service \ predicate:	P	Q	R	S	T
# 	### 			a			*	*	*
# 	### 			b				*	*	*
# 	### 			c			*		*	*
# 	### 			d						*	*
# 	### no single endpoint can answer the whole query, involving a BGP with
# 	### 3 triple patterns, but endpoint 'a' can answer a two-triple-pattern
# 	### subquery (predicates P and Q), then joining with results from endpoint
# 	### 'd' (the single triple-pattern with predicate T).
# 	my @names		= ('a' .. 'd');
# 	my %preds		= (
# 						a	=> [qw(P Q R)],
# 						b	=> [qw(Q R S)],
# 						c	=> [qw(R S P)],
# 						d	=> [qw(S T)],
# 					);
# 	my %sd			= map {
# 						my $port	= 10000 + (ord($_) - ord('a'));
# 						$_ => local_sd( $_, $port, "http://${_}.example.com/", 5, [ map { "ex:$_" } @{ $preds{ $_ } } ] );
# 					} @names;
# 	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1 } );
# 		PREFIX ex: <http://example.org/>
# 		SELECT * WHERE {
# 			?v ex:P ?p ;
# 				ex:Q ?q ;
# 				ex:T ?t .
# 		}
# END
# 	while (my ($name,$sd) = each(%sd)) {
# 		$query->add_service( $sd );
# 	}
# 	my ($plan, $ctx)	= $query->prepare();
# 	my $sse	= $plan->sse({}, '  ');
# 	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan (1)' );
# 		(project (v p q t)
# 			(threshold-union 0
# 				(nestedloop-join
# 					(service <http://127.0.0.1:10000/sparql> "PREFIX ex: <http://example.org/>\nSELECT * WHERE {\n\t?v ex:P ?p .\n\t?v ex:Q ?q .\n}")
# 					(service <http://127.0.0.1:10003/sparql> "PREFIX ex: <http://example.org/>\nSELECT * WHERE {\n\t?v ex:T ?t .\n}"))
# 				(bind-join
# 					(bind-join
# 						(triple ?v <http://example.org/T> ?t)
# 						(triple ?v <http://example.org/Q> ?q))
# 					(triple ?v <http://example.org/P> ?p))
# 			)
# 		)
# END
# }
# 
# sub overlapping_optimistic_bgp_rewriting_test_2 {
# 	### this test uses two endpoint service descriptions, with overlapping
# 	### coverage of four predicates:
# 	### service \ predicate:	P	Q	R	S
# 	### 			a			*	*	*
# 	### 			b				*	*	*
# 	### no single endpoint can answer the whole query, involving a BGP with
# 	### 4 triple patterns, but each endpoint can answer a three-triple-pattern
# 	### subquery, then joining with results with a single-triple-pattern query
# 	### from the other endpoint.
# 	my @names		= (qw(a b));
# 	my %preds		= (
# 						a	=> [qw(P Q R)],
# 						b	=> [qw(Q R S)],
# 					);
# 	my %sd			= map {
# 						my $port	= 10000 + (ord($_) - ord('a'));
# 						$_ => local_sd( $_, $port, "http://${_}.example.com/", 5, [ map { "ex:$_" } @{ $preds{ $_ } } ] );
# 					} @names;
# 	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1 } );
# 		PREFIX ex: <http://example.org/>
# 		SELECT * WHERE {
# 			?v ex:P ?p ;
# 				ex:Q ?q ;
# 				ex:R ?t ;
# 				ex:S ?s .
# 		}
# END
# 	while (my ($name,$sd) = each(%sd)) {
# 		$query->add_service( $sd );
# 	}
# 	my $ctx		= RDF::Query::ExecutionContext->new(
# 		query						=> $query,
# 		optimize					=> 1,
# 		model						=> RDF::Trine::Model->temporary_model,
# 		optimistic_threshold_time	=> 2,
# 	);
# 	my @plans	= $query->query_plan( $ctx );
# 	my $plan	= $plans[0];
# 	my $sse	= $plan->sse({}, '  ');
# 	is( _CLEAN_WS($sse), _CLEAN_WS(<<'END'), 'expected optimistic federation query plan (2)' );
# 		(project (v p q t s)
# 			(threshold-union 2
# 				(nestedloop-join
# 					(service <http://127.0.0.1:10000/sparql> "SELECT * WHERE {\n\t?v <http://example.org/P> ?p .\n\t?v <http://example.org/Q> ?q .\n\t?v <http://example.org/R> ?t .\n}")
# 					(triple ?v <http://example.org/S> ?s))
# 				(nestedloop-join
# 					(service <http://127.0.0.1:10001/sparql> "SELECT * WHERE {\n\t?v <http://example.org/Q> ?q .\n\t?v <http://example.org/R> ?t .\n\t?v <http://example.org/S> ?s .\n}")
# 					(triple ?v <http://example.org/P> ?p))
# 				(bind-join
# 					(bind-join (bind-join (triple ?v <http://example.org/S> ?s) (triple ?v <http://example.org/R> ?t)) (triple ?v <http://example.org/Q> ?q))
# 					(triple ?v <http://example.org/P> ?p))
# 			)
# 		)
# END
# }
# 
# sub simple_optimistic_bgp_rewriting_execution_test {
# 	my %ports		= qw(alice.rdf 8889 bob.rdf 8891);
# 	my $alice_sd	= local_sd( 'alice.rdf', 8889, 'http://work.example/people/', 5, [qw(rdf:type foaf:knows foaf:name)] );
# 	my $bob_sd		= local_sd( 'bob.rdf', 8891, 'http://oldcorp.example.org/bob/', 4, [qw(rdf:type foaf:knows foaf:name)] );
# 	my $query		= RDF::Query::Federate->new( <<"END", { optimize => 1, optimistic_threshold_time => 0 } );
# 		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 		SELECT ?p ?name WHERE {
# 			?p foaf:knows ?knows ; foaf:name ?name.
# 		}
# END
# 	$query->add_service( $alice_sd );
# 	$query->add_service( $bob_sd );
# 	my ($plan, $ctx)	= $query->prepare();
# 	
# 	my %pids;
# 	while (my($name, $model) = each(%models)) {
# 		my $pid	= start_endpoint_for_service( $ports{ $name }, $model );
# 		$pids{ $name }	= $pid;
# 	}
# 	
# 	my $iter	= $query->execute_plan( $plan, $ctx );
# 	
# 	my %names;
# 	my %origins;
# 	my $counter	= 0;
# 	while (my $row = $iter->next) {
# 		my $orig	= join(',', sort @{ $row->label('origin') });
# 		$origins{ $orig }++;
# 		$counter++;
# 		$names{ $row->{name}->literal_value }++;
# 	}
# 	
# 	# we expect to find:
# 	#	- one result with name=Bob from the optimistic BGP sent to bob's server on port 8891
# 	#	- one result with name=Alice from alice's server on port 8889
# 	#	- two results from the local join that merges data from both servers, one with name=Alice, and one with name=Bob
# 	is( $counter, 4, 'expected result count with duplicates from optimistic execution' );
# 	is_deeply( \%names, { Bob => 2, Alice => 2 }, 'expected duplicate result counts per result' );
# 	is_deeply( \%origins, { 'http://127.0.0.1:8889/sparql' => 2, 'http://127.0.0.1:8891/sparql' => 2 }, 'expected originating endpoint distribution' );
# 	
# 	while (my($name, $pid) = each(%pids)) {
# 		kill_endpoint( $pid, $quit_sig );
# 	}
# 	sleep 1;
# }
# 
# sub start_endpoint_for_service {
# 	my $req_port	= shift;
# 	my $model		= shift;
# 	my ($pid, $port)	= RDF::Query::Util::start_endpoint( $model, $req_port++, '../RDF-Endpoint/include' );
# 	return $pid;
# }
# 
# sub kill_endpoint {
# 	my $pid			= shift;
# 	my $quit_sig	= shift;
# 	my $sent		= kill( $quit_sig, $pid );
# }
# 
# sub local_sd {
# 	my $name		= shift;
# 	my $port		= shift;
# 	my $base		= shift;
# 	my $size		= shift;
# 	my $preds		= shift || [];
# 	my $pred_rdf	= join("\n\t", map { "sd:capability [ sd:predicate $_ ] ;" } @$preds);
# 	my $rdf			= sprintf( <<'END', $name, $port, $size, $pred_rdf );
# @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
# @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
# @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
# @prefix sd: <http://darq.sf.net/dose/0.1#> .
# @prefix foaf: <http://xmlns.com/foaf/0.1/> .
# @prefix saddle: <http://www.w3.org/2005/03/saddle/#> .
# @prefix sparql: <http://kasei.us/2008/04/sparql#> .
# @prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
# @prefix exif: <http://www.kanzaki.com/ns/exif#> .
# @prefix dc: <http://purl.org/dc/elements/1.1/> .
# @prefix dcterms: <http://purl.org/dc/terms/> .
# @prefix ex: <http://example.org/> .
# 
# # definition of an endpoint
# [] a sd:Service ;
# 	rdfs:label "SPARQL Endpoint for data from %s" ;
# 	sd:url <http://127.0.0.1:%d/sparql> ;
# 	sd:totalTriples %d ;
# 	%s
# 	.
# END
# 	my $store	= RDF::Trine::Store::DBI->temporary_store();
# 	my $model	= RDF::Trine::Model->new( $store );
# 	my $parser	= RDF::Trine::Parser->new('turtle');
# 	$parser->parse_into_model( $base, $rdf, $model );
# 	return RDF::Query::ServiceDescription->new_with_model( $model );
# }
# 
# sub _CLEAN_WS {
# 	my $string	= shift;
# 	$string		=~ s/^\s+//;
# 	chomp($string);
# 	for ($string) {
# 		s/\s+/ /g;
# 		1 while s/[)]\s+[)]/))/g;
# 	}
# 	return $string;
# }
