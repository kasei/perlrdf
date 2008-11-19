#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use File::Spec;
use Data::Dumper;
use lib qw(../lib lib);
use RDF::Query;

binmode(STDIN, ':utf8');
my @args;
my $input	= (scalar(@ARGV) == 0 or $ARGV[0] eq '-')
			? do { local($/) = undef; <> }
			: do { local($/) = undef; open(my $fh, '<', $ARGV[0]) || die $!; binmode($fh, ':utf8'); push(@args, base => 'file://' . File::Spec->rel2abs($ARGV[0])); <$fh> };
my $query	= RDF::Query->new( $input, { lang => 'sparqlp', @args } );
if ($query) {
	print $query->sse . "\n";
} else {
	warn RDF::Query->error;
}
