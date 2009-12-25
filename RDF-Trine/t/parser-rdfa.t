use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;

use RDF::Trine;
use RDF::Trine::Parser;
use RDF::Trine::Serializer::NTriples::Canonical;

my $tests	= 1;

if ($ENV{RDFTRINE_NETWORK_TESTS}) {
	plan tests => $tests;
} else {
	plan skip_all => 'No network. Set RDFTRINE_NETWORK_TESTS to run these tests.';
	return;
}

my $path	= File::Spec->catfile( $Bin, 'data', 'rdfa' );
my @good	= glob("${path}/test*.xhtml");
my %expect;
foreach my $g (@good) {
	my $f	= $g;
	$f		=~ s/xhtml$/nt/;
	if (-r $f) {
		local($/)	= undef;
		open( my $fh, '<', $f ) or next;
		my $content	= <$fh>;
		$expect{ $g }	= $content;
	}
}
my $serializer	= RDF::Trine::Serializer::NTriples::Canonical->new( onfail=>'space' );


SKIP: {
	eval "use RDF::RDFa::Parser;";
	skip( "Need RDF::RDFa::Parser to run these tests.", $tests ) if ($@);
	foreach my $file (keys %expect) {
		my $expect	= $expect{ $file };
		my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $model	= RDF::Trine::Model->new(RDF::Trine::Store::DBI->temporary_store);
		my $url	= 'file://' . $file;
		my $parser	= RDF::Trine::Parser->new('rdfa');
		$parser->parse_into_model( $url, $data, $model );
		my $got	= $serializer->serialize_model_to_string($model);
		is( $got, $expect );
	}
}
