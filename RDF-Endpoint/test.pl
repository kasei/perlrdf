#!/usr/bin/perl

use strict;
use warnings;
use RDF::Endpoint;
$0		= 'sparql-endpoint';
my $s	= RDF::Endpoint->new( 8082 );
my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
