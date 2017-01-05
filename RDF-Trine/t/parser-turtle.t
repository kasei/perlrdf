use utf8;
use strict;
use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Glob qw(bsd_glob);
use File::Spec;
use URI::file;

use RDF::Trine qw(iri literal);
use RDF::Trine::Parser;


my $path	= File::Spec->catfile( $Bin, 'data', 'turtle' );
my @good	= bsd_glob("${path}/test*.ttl");
my @bad		= bsd_glob("${path}/bad*.ttl");

{
	my $file	= $good[0];
	my $uri		= URI::file->new($file, (($file =~ m#^\w:\\\\#) ? 'win32' : ()));
	my $base	= $uri->as_string;
	my $model = RDF::Trine::Model->temporary_model;
	RDF::Trine::Parser->parse_file_into_model( $base, $file, $model );
	is( $model->size, 1, 'parse_file_into_model, guessed from filename' );
	my $ok = 0;
	RDF::Trine::Parser->parse_file( $base, $file, sub { $ok = 1; } );
	ok( $ok, 'parse_file, guessed from filename' );
}

{
	my $file	= File::Spec->catfile( $Bin, 'data', 'bugs', 'ttl-with-bom.ttl' );
	my $model	= RDF::Trine::Model->temporary_model;
	my $p		= RDF::Trine::Parser::Turtle->new();
	$p->parse_file_into_model( undef, $file, $model );
	is( $model->size, 1, 'expected model size from turtle file with BOM' );
}

foreach my $file (@good) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	lives_ok {
		my $uri	= URI::file->new($file, (($file =~ m#^\w:\\\\#) ? 'win32' : ()));
		my $url	= $uri->as_string;
		my $parser	= RDF::Trine::Parser::Turtle->new();
		$parser->parse( $url, $data );
	} $test;
}

_SILENCE();
foreach my $file (@bad) {
	my $data	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
	my (undef, undef, $test)	= File::Spec->splitpath( $file );
	throws_ok {
		my $uri	= URI::file->new($file, (($file =~ m#^\w:\\\\#) ? 'win32' : ()));
		my $url	= $uri->as_string;
		my $parser	= RDF::Trine::Parser::Turtle->new();
		$parser->parse( $url, $data );
	} 'RDF::Trine::Error::ParserError', $test;
}

{
	# Canonicalization tests
	my $parser	= RDF::Trine::Parser::Turtle->new( canonicalize => 1 );
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
}	

{
	my $parser	= RDF::Trine::Parser::Turtle->new();
	my $model = RDF::Trine::Model->temporary_model;
	my $ttl		= <<'END';
# This document contains a graph with non-ASCII chars.
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://www.example.org/vocabulary#> .
_:a foaf:name "Bob" . 
_:a ex:likes "Blåbærsyltetøy"@no .
END
	$parser->parse_into_model(undef, $ttl, $model);
	my $iter = $model->get_statements( undef, iri('http://www.example.org/vocabulary#likes'), undef );
	my $st = $iter->next;
	my $got		= $st->object->literal_value;
	my $expect	= 'Blåbærsyltetøy';
	is($got, $expect, "Finding UTF-8 string");
}

done_testing();

sub _SILENCE {
	Log::Log4perl->init( {
		"log4perl.rootLogger"				=> "FATAL, screen",
		"log4perl.appender.screen"			=> "Log::Log4perl::Appender::Screen",
		"log4perl.appender.screen.stderr"	=> 1,
		"log4perl.appender.screen.layout"	=> 'Log::Log4perl::Layout::SimpleLayout',
	} );
}
