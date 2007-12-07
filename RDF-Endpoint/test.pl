#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);
use RDF::Endpoint::Server;
$0		= 'sparql-endpoint';
my $s	= RDF::Endpoint::Server->new( 8082 );
my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
