#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);

use File::Spec;
use URI::file;
use RDF::Query;
use RDF::Query::Util;
binmode( \*STDOUT, ':utf8' );

unless (@ARGV) {
	print STDERR <<"END";
USAGE:
       $0 -e 'SELECT * ...' data.rdf [ ... ]
       $0 -E http://service.example/sparql -e 'SELECT * ...'
       $0 -F path/to/service_description.ttl -e 'SELECT * ...'
       $0 query.rq data.rdf

Reads in a SPARQL query from query.rq (or specified with the -e flag), and
RDF/XML data from the data.rdf files. The SPARQL query is executed against a
triplestore containing data from the data files, and query results are printed
to standard output.

END
	exit;
}

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.util		= DEBUG, Screen
# 	log4perl.category.rdf.query.plan.thresholdunion		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

# construct a query from the command line arguments
my ($query, $model)	= &RDF::Query::Util::cli_make_query_and_model;
unless ($query and $model) {
	die RDF::Query->error;
}

# execute the query against data contained in the model
my $iter	= $query->execute( $model );

# print the results as a string to standard output
print $iter->as_string;

### this will allow the results to be printed in a streaming fashion:
### or, if you want to iterate over each result row:
# while (my $s = $iter->next) {
# 	print $s . "\n";
# }
