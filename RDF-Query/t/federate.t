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

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.thresholdunion          = TRACE, Screen
# 	log4perl.category.rdf.query.servicedescription           = DEBUG, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my %named	= map { $_ => File::Spec->rel2abs("data/federation_data/$_") } qw(alice.rdf bob.rdf);
my %models	= map { $_ => RDF::Query::Util::make_model( $named{$_} ) } (keys %named);

eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} else {
	plan qw(no_plan); #tests => scalar(@models) * $model_tests + $nomodel_tests;
}

################################################################################

bgp_rewriting_test();

################################################################################

sub bgp_rewriting_test {
	{
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
(project (p knows) (threshold-union 
          (service <http://127.0.0.1:8891/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
          (service <http://127.0.0.1:8889/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nSELECT * WHERE {\n\t?p <http://xmlns.com/foaf/0.1/knows> ?knows .\n\t?knows a <http://xmlns.com/foaf/0.1/Person> .\n}")
          (bind-join (triple ?knows <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>) (triple ?p <http://xmlns.com/foaf/0.1/knows> ?knows))))
END
		
### If we were to start an RDF::Endpoint server on the appropriate ports, this should work:
# 		my $iter	= $query->execute_plan( $plan, $ctx );
# 		while (my $row = $iter->next) {
# 			print "$row\n";
# 		}
	}
}

sub execution_test {
	my $quit_sig		= 1;
	my @sigs	= split(' ', $Config{sig_name});
	foreach my $i (0 .. $#sigs) {
		if ($sigs[$i] eq 'QUIT') {
			$quit_sig	= $i;
			last;
		}
	}
	
	my %ports;
	my %pids;
	my $req_port	= 8891;
	while (my($name, $model) = each(%models)) {
	# 	print "\n#################################\n";
	# 	print "### Using model: $model loaded with $name\n\n";
	# 	
		my ($pid, $port)	= RDF::Query::Util::start_endpoint( $model, $req_port++, '../RDF-Endpoint/include' );
		$pids{ $name }	= $pid;
		$ports{ $name }	= $port;
		ok( $pid, "got pid ($pid)" );
	}
	
	###########################
	# XXX
	print "# type ENTER to continue\n";
	<STDIN>;
	###########################
	
	while (my($name, $pid) = each(%pids)) {
		warn "killing server for $name";
		my $sent	= kill( $quit_sig, $pid );
		is( $sent, 1, "sent server kill signal" );
		sleep(5);
	}
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
	chomp($string);
	for ($string) {
		s/\s+/ /g;
		1 while s/[)]\s+[)]/))/g;
	}
	return $string;
}
