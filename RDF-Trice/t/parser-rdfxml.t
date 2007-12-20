use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use File::Slurp;

plan skip_all => "RDF/XML parser hasn't been written yet.";
exit;

use_ok( 'RDF::Trice::Parser::RDFXML' );

my $path	= File::Spec->catfile( $Bin, 'data', 'rdfxml' );
my @good	= glob("${path}/ex*.rdf");
my @bad		= glob("${path}/bad*.rdf");

foreach my $file (@good) {
	my $data	= read_file( $file );
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	lives_ok {
		my $url	= 'file://' . $file;
		my $doc	= RDF::Trice::Parser::RDFXML->new( $url, $data );
		$doc->parse();
	} $test;
}

foreach my $file (@bad) {
	my $data	= read_file( $file );
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	throws_ok {
		my $url	= 'file://' . $file;
		my $doc	= RDF::Trice::Parser::RDFXML->new( $url, $data );
		$doc->parse();
	} 'RDF::Trice::Parser::Error::ValueError', $test;
}
