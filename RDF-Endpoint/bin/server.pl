#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use lib qw(lib ../RDF-Store-DBI/lib ../RDF-SPARQLResults/lib);
use RDF::Endpoint::Server;
$0		= 'sparql-endpoint';

$ENV{TMPDIR}	= '/tmp';
my $cgi	= CGI->new;
my $s	= RDF::Endpoint::Server->new(
			Port		=> 8082,
			DBServer	=> $ENV{RDFQUERY_DBI_DATABASE} || 'DBI:mysql:database=test',
			DBUser		=> $ENV{RDFQUERY_DBI_USER} || 'test',
			DBPass		=> $ENV{RDFQUERY_DBI_PASS} || 'test',
			Model		=> $ENV{RDFQUERY_DBI_MODEL} || 'endpoint',
			Prefix		=> '',
			CGI			=> $cgi,
		);

my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
