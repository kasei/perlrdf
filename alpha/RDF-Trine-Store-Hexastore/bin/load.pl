#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);

use RDF::Trine;
use RDF::Trine::Store::Hexastore;

if (scalar(@ARGV) < 2) {
	warn "Usage: $0 filename.out input.rdf [input2.rdf ...]\n\n";
	exit;
}

my $outname	= shift;
my $store	= RDF::Trine::Store::Hexastore->new();

while (my $inname = shift) {
	my $base	= 'file://' . File::Spec->rel2abs($inname);
	my $parser	= RDF::Trine::Parser::RDFXML->new();
	my $data	= do { open( my $fh, '<', $inname ) or die $!; local($/) = undef; <$fh> };
	$parser->parse_into_model( $base, $data, $store );
}

$store->store( $outname );
