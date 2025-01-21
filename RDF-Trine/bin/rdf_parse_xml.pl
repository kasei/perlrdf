#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use lib qw(lib);
use Data::Dumper;
use FindBin qw($Bin);
use LWP::Simple qw(get);

use RDF::Trine::Model;
use RDF::Trine::Store::DBI;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Serializer::NTriples;

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

my $model	= RDF::Trine::Model->new( RDF::Trine::Store::DBI->temporary_store );
my $parser	= RDF::Trine::Parser::RDFXML->new( BNodePrefix => 'genid' );
$parser->parse_into_model( $url, $data, $model );

my $s		= RDF::Trine::Serializer::NTriples->new();
my $nt		=  $s->serialize_model_to_string( $model );
print $nt;
