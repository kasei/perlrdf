#!/usr/bin/env perl

use strict;
use warnings;
use RDF::Query;

unless (@ARGV) {
	print STDERR <<"END";
USAGE: $0 query.rq http://path/to/data.rdf

Reads in a SPARQL query from query.rq, and loads RDF data from the supplied URL.
The SPARQL query is executed against a triplestore containing the loaded RDF,
and query results are printed to standard output.

END
	exit;
}

# get the query file from the arguments array
my $query_file	= shift(@ARGV);

#open the query file and read in the query
my $sparql	= do { local($/) = undef; open(my $fh, '<:utf8', $query_file); <$fh> };

# construct the query object
my $query	= RDF::Query->new( $sparql );

unless ($query) {
	# the query couldn't be constructed. print out the reason why.
	warn RDF::Query->error;
	exit;
}

# create a temporary triplestore (in memory), and wrap it into a model
my $store	= RDF::Trine::Store::DBI->temporary_store();
my $model	= RDF::Trine::Model->new( $store );


# load the RDF data from the url into the model.
# the parse_url_into_model method will attempt to guess the appropriate format for parsing.
my $url	= shift(@ARGV);
RDF::Trine::Parser->parse_url_into_model( $url, $model );

# execute the query against data contained in the model
my $iter	= $query->execute( $model );

# print the results as a string to standard output
print $iter->as_string;

### or, if you want to iterator over each result row:
# while (my $s = $iter->next) {
# 	print $s . "\n";
# }
