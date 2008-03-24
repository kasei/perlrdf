use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;

plan qw(no_plan);

use_ok( 'RDF::Trine::Parser::RDFXML' );

my $path	= File::Spec->catfile( $Bin, 'data', 'rdfxml' );
my @good	= glob("${path}/ex*.rdf");
my @bad		= glob("${path}/bad*.rdf");

foreach my $file (@good) {
	TODO: {
		local($TODO)	= 'rdf/xml parser is currently broken' if ($file =~ m/ex-(19|37|45|46|53|58)/);
		my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		lives_ok {
			my $url	= 'file://' . $file;
			my $doc	= RDF::Trine::Parser::RDFXML->new();
			$doc->parse( $url, $data );
		} $test;
	}
}

foreach my $file (@bad) {
	TODO: {
		local($TODO)	= 'rdf/xml parser is currently broken' if ($file =~ m/bad-(00|01|02|03|04|05|10|11|12|14|15|16|17|18|19|20|22)/);
		my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		throws_ok {
			my $url	= 'file://' . $file;
			my $doc	= RDF::Trine::Parser::RDFXML->new();
			$doc->parse( $url, $data );
		} 'RDF::Trine::Parser::Error::ValueError', $test;
	}
}
