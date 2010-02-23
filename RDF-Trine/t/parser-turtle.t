use Test::More qw(no_plan);
use Test::Exception;
use FindBin qw($Bin);
use File::Glob qw(bsd_glob);
use File::Spec;

use RDF::Trine;
use RDF::Trine::Parser;


my $path	= File::Spec->catfile( $Bin, 'data', 'turtle' );
my @good	= bsd_glob("${path}/test*.ttl");
my @bad		= bsd_glob("${path}/bad*.ttl");

foreach my $file (@good) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	lives_ok {
		my $url	= 'file://' . $file;
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse( $url, $data );
	} $test;
}

_SILENCE();
foreach my $file (@bad) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	throws_ok {
		my $url	= 'file://' . $file;
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse( $url, $data );
	} 'RDF::Trine::Error::ParserError', $test;
}


sub _SILENCE {
	Log::Log4perl->init( {
		"log4perl.rootLogger"				=> "FATAL, screen",
		"log4perl.appender.screen"			=> "Log::Log4perl::Appender::Screen",
		"log4perl.appender.screen.stderr"	=> 1,
		"log4perl.appender.screen.layout"	=> 'Log::Log4perl::Layout::SimpleLayout',
	} );
}
