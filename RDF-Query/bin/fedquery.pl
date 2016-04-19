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
USAGE: perl $0 query.rq [ service.rdf, ... ]

Executes a SPARQL query against the endpoints described in the specified
service descriptions.

END
	exit;
}

my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;

my @files	= @ARGV;
foreach my $file (@files) {
	my $uri	= URI::file->new_abs( $file );
	my $sd	= RDF::Query::ServiceDescription->new_from_uri( $uri );
	$query->add_service( $sd );
}
my ($plan, $ctx)	= $query->prepare();
my $iter			= $query->execute_plan( $plan, $ctx );
while (my $row = $iter->next) {
	print "$row\n";
}
