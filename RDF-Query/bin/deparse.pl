#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query;
use RDF::Query::Util;

my %args	= (optimize => 1, &RDF::Query::Util::cli_parse_args);
my $sparql	= delete $args{ query };
my $query	= RDF::Query->new( $sparql, \%args ) or die RDF::Query->error;
print $query->as_sparql;
