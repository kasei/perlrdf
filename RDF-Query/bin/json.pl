#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use lib qw(../lib lib);

use JSON;
use Data::Dumper;
use RDF::Query;
use RDF::Query::Util;

my $json	= new JSON;
my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;

# my $pattern	= $query->pattern;
my ($pattern)	= $query->pattern->subpatterns_of_type( 'RDF::Query::Algebra::GroupGraphPattern' );
my $hash		= $pattern->as_hash;

# print $json->pretty->encode($hash);
print $json->encode($hash);
