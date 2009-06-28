#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use lib qw(lib ../RDF-Query/lib ../RDF-Store-DBI/lib ../RDF-SPARQLResults/lib);

use RDF::Query::Util;
use RDF::Endpoint::Server;

$0		= 'sparql-endpoint';

$ENV{TMPDIR}	= '/tmp';
my $cgi	= CGI->new;
my $port		= 8082;
if (@ARGV) {
	if ($ARGV[0] eq '-p') {
		shift(@ARGV);
		$port	= shift(@ARGV);
	}
}
my $model = &RDF::Query::Util::cli_make_model;
my $s	= RDF::Endpoint::Server->new_with_model( $model,
			Port		=> $port,
			Prefix		=> '',
			CGI			=> $cgi,
		);

my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
