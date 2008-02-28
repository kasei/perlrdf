use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use File::Slurp;

plan qw(no_plan);

use_ok( 'RDF::Trine::Parser::RDFXML' );

my $path	= File::Spec->catfile( $Bin, 'data', 'rdfxml' );
my @good	= glob("${path}/ex*.rdf");
my @bad		= glob("${path}/bad*.rdf");

foreach my $file (@good) {
	my $data	= read_file( $file );
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	lives_ok {
		my $url	= 'file://' . $file;
		my $doc	= RDF::Trine::Parser::RDFXML->new();
		$doc->parse( $url, $data );
	} $test;
}

foreach my $file (@bad) {
	my $data	= read_file( $file );
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	throws_ok {
		my $url	= 'file://' . $file;
		my $doc	= RDF::Trine::Parser::RDFXML->new();
		$doc->parse( $url, $data );
	} 'RDF::Trine::Parser::Error::ValueError', $test;
}
