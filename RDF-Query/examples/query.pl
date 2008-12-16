#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);

use File::Spec;
use URI::file;
use RDF::Query;

unless (@ARGV) {
	print STDERR <<"END";
USAGE: $0 -e 'SELECT * ...' data.rdf
USAGE: $0 query.rq data.rdf

END
	exit;
}

my $sparql;
my $file	= shift;
if ($file eq '-e') {
	$sparql	= shift;
} else {
	$sparql	= do { local($/) = undef; open( my $fh, '<', $file ) or die $!; <$fh> };
}

my @files	= map { File::Spec->rel2abs( $_ ) } @ARGV;
my @uris	= map { URI::file->new_abs( $_ ) } @files;
my $store	= RDF::Trine::Store::DBI->temporary_store();
my $model	= RDF::Trine::Model->new( $store );
my $parser	= RDF::Trine::Parser->new('rdfxml');
my $handler	= sub { my $st	= shift; $model->add_statement( $st ) };
foreach my $i (0 .. $#files) {
	my $file	= $files[ $i ];
	my $uri		= $uris[ $i ];
	my $content	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	$parser->parse( $uri, $content, $handler );
}

my $query	= RDF::Query->new( $sparql );
my $iter	= $query->execute( $model );

print $iter->as_string;

### or, if you want to iterator over each result row:
# while (my $s = $iter->next) {
# 	print $s . "\n";
# }
