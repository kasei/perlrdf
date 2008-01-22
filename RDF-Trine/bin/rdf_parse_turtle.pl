#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Slurp;
use lib qw(lib);
use FindBin qw($Bin);
use RDF::Trine::Parser::Turtle;

my $file	= File::Spec->rel2abs( shift );
my $data	= read_file( $file );
my $url		= 'file://' . $file;
my $doc		= RDF::Trine::Parser::Turtle::Document->new( $url, $data );
$doc->parse();
