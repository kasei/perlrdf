use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Glob qw(bsd_glob);
use File::Spec;

use RDF::Trine qw(literal);
use RDF::Trine::Parser;
use RDF::Trine::Parser::Redland;

if ($RDF::Trine::Parser::Redland::HAVE_REDLAND_PARSER) {
	plan qw(no_plan);
} else {
	plan skip_all => "Redland parser is not available.";
}

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

{
	# Canonicalization tests
	my $parser	= RDF::Trine::Parser->new( 'turtle', canonicalize => 1 );
	{
		my $model = RDF::Trine::Model->temporary_model;
		my $ntriples	= qq[_:a <http://example.com/integer> "-0123"^^<http://www.w3.org/2001/XMLSchema#integer> .\n];
		$parser->parse_into_model(undef, $ntriples, $model);
		is( $model->count_statements(undef, undef, literal('-123', undef, 'http://www.w3.org/2001/XMLSchema#integer')), 1, 'expected 1 count for canonical integer value' );
	}
	{
		my $model = RDF::Trine::Model->temporary_model;
		my $ntriples	= qq[_:a <http://example.com/integer> "+0000123"^^<http://www.w3.org/2001/XMLSchema#integer> .\n];
		$parser->parse_into_model(undef, $ntriples, $model);
		is( $model->count_statements(undef, undef, literal('123', undef, 'http://www.w3.org/2001/XMLSchema#integer')), 1, 'expected 1 count for canonical integer value' );
	}
	{
		my $model = RDF::Trine::Model->temporary_model;
		my $ntriples	= qq[_:a <http://example.com/decimal> "+100000.00"^^<http://www.w3.org/2001/XMLSchema#decimal> .\n];
		$parser->parse_into_model(undef, $ntriples, $model);
		is( $model->count_statements(undef, undef, literal('100000.0', undef, 'http://www.w3.org/2001/XMLSchema#decimal')), 1, 'expected 1 count for canonical decimal value' );
	}
	{
		my $model = RDF::Trine::Model->temporary_model;
		my $ntriples	= qq[_:a <http://example.com/decimal> "0"^^<http://www.w3.org/2001/XMLSchema#boolean> .\n];
		$parser->parse_into_model(undef, $ntriples, $model);
		is( $model->count_statements(undef, undef, literal('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean')), 1, 'expected 1 count for canonical boolean value' );
	}
	{
		my $model = RDF::Trine::Model->temporary_model;
		my $ntriples	= qq[_:a <http://example.com/decimal> "1"^^<http://www.w3.org/2001/XMLSchema#boolean> .\n];
		$parser->parse_into_model(undef, $ntriples, $model);
		is( $model->count_statements(undef, undef, literal('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')), 1, 'expected 1 count for canonical boolean value' );
	}

	TODO: {
		  local $TODO = 'UTF8 problems with Redland';
		  my $model = RDF::Trine::Model->temporary_model;
		  my $ntriples	= '<http://example.com/a> <http://example.com/b> "bl\\u00C3\\u00A5b\\u00C3\\u00A6rsyltet\\u00C3\\u00B8y"@nb .';
		  $parser->parse_into_model(undef, $ntriples, $model);
		  my $iter	= $model->as_stream;
		  my $st = $iter->next;
		  isa_ok( $st, 'RDF::Trine::Statement' );
		  is($st->object->literal_value, 'blåbærsyltetøy', 'expected triple object value with utf8 chars' );
	  }

}	


sub _SILENCE {
	Log::Log4perl->init( {
		"log4perl.rootLogger"				=> "FATAL, screen",
		"log4perl.appender.screen"			=> "Log::Log4perl::Appender::Screen",
		"log4perl.appender.screen.stderr"	=> 1,
		"log4perl.appender.screen.layout"	=> 'Log::Log4perl::Layout::SimpleLayout',
	} );
}
