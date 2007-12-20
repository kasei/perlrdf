#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib ../RDF-Store-DBI/lib ../RDF-SPARQLResults/lib);
use RDF::Endpoint::Server;
$0		= 'sparql-endpoint';
$ENV{TMPDIR}	= '/tmp';
my $s	= RDF::Endpoint::Server->new(
			Port		=> 8082,
			DBServer	=> $ENV{DBServer} || 'DBI:mysql:database=test',
			DBUser		=> $ENV{DBUser} || 'test',
			DBPass		=> $ENV{DBPass} || 'test',
			Model		=> 'endpoint',
			Prefix		=> '',
		);
my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
