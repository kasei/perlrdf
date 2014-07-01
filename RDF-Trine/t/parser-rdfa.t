use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;

use RDF::Trine qw(literal);
use RDF::Trine::Parser;
use RDF::Trine::Serializer::NTriples::Canonical;


my $path	= File::Spec->catfile( $Bin, 'data', 'rdfa' );
my @good	= glob("${path}/test*.xhtml");
my $tests	= 2 * scalar(@good);
plan tests => $tests;

my %expect;
my %names;
foreach my $g (@good) {
	my $f	= $g;
	$f		=~ s/xhtml$/nt/;
	if (-r $f) {
		local($/)	= undef;
		open( my $fh, '<', $f ) or next;
		my $content	= <$fh>;
		$expect{ $g }	= $content;
		(undef, undef, my $name)	= File::Spec->splitpath( $g );
		$names{ $g }	= $name;
	}
}
my $serializer	= RDF::Trine::Serializer::NTriples::Canonical->new( onfail=>'space' );


SKIP: {
	eval "use RDF::RDFa::Parser 0.30;";
	skip( "Need RDF::RDFa::Parser to run these tests.", $tests ) if ($@);
	if ($RDF::Trine::VERSION =~ /_/) {
		diag "Using RDF::RDFa::Parser $RDF::RDFa::Parser::VERSION";
	}
	foreach my $file (keys %expect) {
		my $expect	= $expect{ $file };
		my $name	= $names{ $file };
		
		{
			my $parser	= RDF::Trine::Parser->new('rdfa');
			my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
			my (undef, undef, $test)	= File::Spec->splitpath( $file );
			my $model	= RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
			my $url	= 'file://' . $file;
			$parser->parse_into_model( $url, $data, $model );
			my $got	= $serializer->serialize_model_to_string($model);
			foreach ($got, $expect) { s/[\r\n]+/\n/g }
			is( $got, $expect, "parse_into_model: $name" );
		}
		
		{
			my $parser	= RDF::Trine::Parser->new('rdfa');
			my $url	= 'file://' . $file;
			my $model	= RDF::Trine::Model->temporary_model;
			$parser->parse_file_into_model( $url, $file, $model );
			my $got	= $serializer->serialize_model_to_string($model);
			foreach ($got, $expect) { s/[\r\n]+/\n/g }
			is( $got, $expect, "parse_file_into_model: $name" );
		}
		
	}
}
