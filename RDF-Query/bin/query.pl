#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);

use File::Spec;
use URI::file;
use RDF::Query;
use RDF::Query::Util;

unless (@ARGV) {
	print STDERR <<"END";
USAGE: $0 -e 'SELECT * ...' data.rdf [ ... ]
USAGE: $0 query.rq data.rdf

Reads in a SPARQL query from query.rq (or specified with the -e flag), and
RDF/XML data from the data.rdf files. The SPARQL query is executed against a
triplestore containing data from the data files, and query results are printed
to standard output.

END
	exit;
}

################################################################################
Log::Log4perl::init( \q[
	log4perl.category.rdf.query.util		= DEBUG, Screen
	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
	log4perl.appender.Screen.stderr			= 0
	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
] );
################################################################################

# construct a query from the command line arguments
my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;

my $model	= &RDF::Query::Util::cli_make_model( @ARGV );

# execute the query against data contained in the model
my $iter	= $query->execute( $model );

# print the results as a string to standard output
print $iter->as_string;

### or, if you want to iterator over each result row:
# while (my $s = $iter->next) {
# 	print $s . "\n";
# }
