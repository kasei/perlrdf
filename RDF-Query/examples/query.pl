#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);

use File::Spec;
use URI::file;
use RDF::Query;

unless (@ARGV) {
	print STDERR <<"END";
USAGE: $0 query.rq data.rdf [ data2.rdf ... ]

Reads in a SPARQL query from query.rq, and RDF/XML data from the data.rdf files.
The SPARQL query is executed against a triplestore containing data from the
data files, and query results are printed to standard output.

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

# read in the list of files with RDF/XML content for querying
my @files	= map { File::Spec->rel2abs( $_ ) } @ARGV;

# create a temporary triplestore, and wrap it into a model
my $store	= RDF::Trine::Store::DBI->temporary_store();
my $model	= RDF::Trine::Model->new( $store );

# create a rdf/xml parser object that we'll use to read in the rdf data
my $parser	= RDF::Trine::Parser->new('rdfxml');

# loop over all the files
foreach my $i (0 .. $#files) {
	my $file	= $files[ $i ];
	# $uri is the URI object used as the base uri for parsing
	my $uri		= URI::file->new_abs( $file );
	my $content	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	$parser->parse_into_model( $uri, $content, $model );
}

# execute the query against data contained in the model
my $iter	= $query->execute( $model );

# print the results as a string to standard output
print $iter->as_string;

### or, if you want to iterator over each result row:
# while (my $s = $iter->next) {
# 	print $s . "\n";
# }
