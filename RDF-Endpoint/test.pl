#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);
use RDF::Endpoint::Server;
$0		= 'sparql-endpoint';
$ENV{TMPDIR}	= '/tmp';
my $s	= RDF::Endpoint::Server->new(
			Port		=> 8082,
			DBServer	=> 'DBI:mysql:database=test',
			DBUser		=> 'test',
			DBPass		=> 'test',
			Model		=> 'endpoint',
		);
my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
