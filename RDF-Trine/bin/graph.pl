#!/usr/bin/env perl

use strict;
use warnings;
use RDF::Trine;
use GraphViz;
use File::Spec;

my $model	= RDF::Trine::Model->temporary_model;
foreach my $file (@ARGV) {
	my $pclass	= RDF::Trine::Parser->guess_parser_by_filename($file) || 'RDF::Trine::Parser::RDFXML';
	my $p	= $pclass->new;
	open(my $fh, '<', $file) or die $!;
	my $base	= 'file://' . File::Spec->rel2abs($file);
	$p->parse_file_into_model( $base, $fh, $model );
}
my $g	= $model->as_graphviz;
print $g->as_png;
