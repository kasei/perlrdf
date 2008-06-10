use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use File::Find qw(find);

use RDF::Trine::Model;
use RDF::Trine::Store::DBI;
use RDF::Trine::Serializer::NTriples;

plan qw(no_plan);

use_ok( 'RDF::Trine::Parser::RDFXML' );

my $path	= File::Spec->catfile( $Bin, 'data', 'rdfxml' );
my @good	= glob("${path}/ex*.rdf");
my @bad		= glob("${path}/bad*.rdf");

my $s		= RDF::Trine::Serializer::NTriples->new();
foreach my $file (@good) {
	TODO: {
		my (undef, undef, $filename)	= File::Spec->splitpath( $file );
		local($TODO)	= 'rdf/xml parser is currently broken'; # if ($file =~ m/ex-(19|37|45|46|53|58)/);
		my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $nt;
		lives_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::RDFXML->new( BNodePrefix => 'genid' );
			my $model	= RDF::Trine::Model->new( RDF::Trine::Store::DBI->temporary_store );
			$parser->parse_into_model( $url, $data, $model );
			$nt			=  $s->serialize_model_to_string( $model );
		} $test;
		
		compare( $nt, $file );
	}
}

foreach my $file (@bad) {
	TODO: {
		local($TODO)	= 'rdf/xml parser is currently broken'; # if ($file =~ m/bad-(00|01|02|03|04|05|10|11|12|14|15|16|17|18|19|20|22)/);
		my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		throws_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::RDFXML->new( BNodePrefix => 'genid' );
			$parser->parse( $url, $data );
		} 'RDF::Trine::Parser::Error::ValueError', $test;
	}
}




sub compare {
	my $nt		= shift;
	my $file	= shift;
	my ($name)	= $file =~ m<^.*/(.*)[.]rdf>;
	$file		=~ s/[.]rdf$/.out/;
	open( my $fh, '<', $file );
	my $got		= join("\n", sort split(/\n/, $nt));
	my $expect	= join('', sort <$fh>);
	chomp($expect);
	is( $got, $expect, "expected triples: $name" );
}
