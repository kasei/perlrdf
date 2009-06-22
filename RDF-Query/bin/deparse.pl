#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query;
use RDF::Query::Util;

my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;
print $query->as_sparql;
