#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use lib qw(lib);
use Data::Dumper;
use FindBin qw($Bin);
use LWP::Simple qw(get);
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Error qw(:try);

my $url		= shift;
my $data;
if ($url =~ m#^http://#) {
	$data	= get($url);
} else {
	my $file	= File::Spec->rel2abs( $url );
	$data	= do {
					open( my $fh, '<:encoding(UTF-8)', $file );
					local($/) = undef;
					<$fh>
				};
	$url		= 'file://' . $file;
}

try {
	my $parser	= RDF::Trine::Parser::Turtle->new;
	$parser->parse( $url, $data, sub { my $st = shift; print $st->as_string . "\n" } );
} otherwise {
	my $e	= shift;
	warn "*** parse error: $e";
}
