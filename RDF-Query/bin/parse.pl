#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';

use File::Spec;
use Data::Dumper;
use lib qw(../lib lib);
use RDF::Query;
use RDF::Query::Util;
use JSON;
use Data::Dumper;

unless (@ARGV) {
	print STDERR <<"END";
USAGE: $0 -e 'SELECT * ...'
USAGE: $0 query.rq

END
	exit;
}

my $query	= &RDF::Query::Util::cli_make_query;
if ($query) {
	print $query->sse . "\n";
	print to_json( $query->as_hash, { ascii => 1, pretty => 1, allow_blessed => 0 } );
} else {
	warn RDF::Query->error;
}
