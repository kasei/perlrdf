#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query;

binmode(STDIN, ':utf8');
my $input	= (scalar(@ARGV) == 0 or $ARGV[0] eq '-')
			? do { local($/) = undef; <> }
			: do { local($/) = undef; open(my $fh, '<', $ARGV[0]); binmode($fh, ':utf8'); <$fh> };

my $query	= RDF::Query->new( $input );
print $query->as_sparql;
