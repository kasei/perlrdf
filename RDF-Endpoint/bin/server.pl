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
			DBServer	=> $ENV{DBServer} || 'DBI:mysql:database=test',
			DBUser		=> $ENV{DBUser} || 'test',
			DBPass		=> $ENV{DBPass} || 'test',
			Model		=> 'endpoint',
			Prefix		=> '',
			CGI			=> $cgi,
		);

my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
