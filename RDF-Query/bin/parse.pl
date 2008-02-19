#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use lib qw(../lib lib);
use RDF::Query::Parser::SPARQL;

binmode(STDIN, ':utf8');
my $input	= (scalar(@ARGV) == 0 or $ARGV[0] eq '-')
			? do { local($/) = undef; <> }
			: do { local($/) = undef; open(my $fh, '<', $ARGV[0]); binmode($fh, ':utf8'); <$fh> };
my $parser	= new RDF::Query::Parser::SPARQL ();
my $parsed	= $parser->parse( $input );
if ($parsed) {
	print Dumper($parsed);
} else {
	warn $parser->error;
}
