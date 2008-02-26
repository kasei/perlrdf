#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use File::Slurp;
use lib qw(lib);
use FindBin qw($Bin);
use RDF::Trine::Parser::Turtle;

my $file	= File::Spec->rel2abs( shift );
my $data	= read_file( $file );
my $url		= 'file://' . $file;
my $parser	= RDF::Trine::Parser::Turtle->new;
$parser->parse( $url, $data );
