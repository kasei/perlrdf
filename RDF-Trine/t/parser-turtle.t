use Test::More qw(no_plan);
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;

use_ok( 'RDF::Trine::Parser' );

my $path	= File::Spec->catfile( $Bin, 'data', 'turtle' );
my @good	= glob("${path}/test*.ttl");
my @bad		= glob("${path}/bad*.ttl");

foreach my $file (@good) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	lives_ok {
		my $url	= 'file://' . $file;
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse( $url, $data );
	} $test;
}

foreach my $file (@bad) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	throws_ok {
		my $url	= 'file://' . $file;
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse( $url, $data );
	} 'RDF::Trine::Parser::Error::ValueError', $test;
}
