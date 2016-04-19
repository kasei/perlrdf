#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);

use RDF::Query::Util;
use RDF::Query::Federate;

use List::Util qw(first);

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.util				= DEBUG, Screen
# 	log4perl.category.rdf.query.federate			= TRACE, Screen
# 	log4perl.category.rdf.query.plan.service		= DEBUG, Screen
# 	log4perl.category.rdf.query.plan.triple			= TRACE, Screen
# 	log4perl.category.rdf.query.model				= DEBUG, Screen
# 	log4perl.category.rdf.query.servicedescription	= DEBUG, Screen
# 	log4perl.appender.Screen						= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr					= 0
# 	log4perl.appender.Screen.layout					= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 [-F path/to/service_description.ttl] query.rq

Attempts to optimize a federated SPARQL query using the endpoints described in
the specified service descriptions. Each optimized query plan is printed as
output.

END
	exit;
}

my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;
my $model	= &RDF::Query::Util::cli_make_model;
my $context	= RDF::Query::ExecutionContext->new(
				bound		=> {},
				model		=> $model,
				query		=> $query,
				optimize	=> 1,
			);
my @plans	= $query->query_plan( $context );

my %plans;
foreach my $i (0 .. $#plans) {
	my $name	= "plan $i";
	print "$name: " . $plans[$i]->sse( {}, ' 'x8 ) . "\n";
}

