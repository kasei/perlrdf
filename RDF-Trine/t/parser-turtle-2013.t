use utf8;
use strict;
use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Glob qw(bsd_glob);
use File::Spec;
use Data::Dumper;
use RDF::Trine qw(iri literal);
use RDF::Trine::Namespace qw(rdf);
use URI::file;
use TryCatch;

my $mf		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
my $rdft	= RDF::Trine::Namespace->new('http://www.w3.org/ns/rdftest#');
my $base	= iri('http://www.w3.org/2013/TurtleTests/');
my $model	= RDF::Trine::Model->temporary_model;

my $path	= File::Spec->catfile( $Bin, '..', 't', 'data', 'turtle-2013' );
my $file	= URI::file->new_abs( File::Spec->catfile($path, 'manifest.ttl') )->as_string;
RDF::Trine::Parser->parse_url_into_model( $file, $model, canonicalize => 1 );

my @manifests	= $model->subjects($rdf->type, $mf->Manifest);
foreach my $manifest (@manifests) {
	my ($list)		= $model->objects($manifest, $mf->entries);
	my @list		= $model->get_list($list);

	my @syntax_good;
	my @syntax_bad;
	my @eval_good;
	my @eval_bad;
	foreach my $test (@list) {
		my ($type)	= $model->objects($test, $rdf->type);
		if ($type->equal($rdft->TestTurtlePositiveSyntax)) {
			push(@syntax_good, $test);
		} elsif ($type->equal($rdft->TestTurtleNegativeSyntax)) {
			push(@syntax_bad, $test);
		} elsif ($type->equal($rdft->TestTurtleEval)) {
			push(@eval_good, $test);
		} elsif ($type->equal($rdft->TestTurtleNegativeEval)) {
			push(@eval_bad, $test);
		} else {
			warn "unrecognized test type $type\n";
		}
	}

	note("Positive Syntax Tests");
	foreach my $test (@syntax_good) {
		my ($test_file)	= $model->objects($test, $mf->action);
		my $file	= URI->new($test_file->uri)->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			fail("$test: $!");
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		lives_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} $test;
	}

	note("Negative Syntax Tests");
	foreach my $test (@syntax_bad) {
		my ($test_file)	= $model->objects($test, $mf->action);
		my $url		= URI->new($test_file->uri);
		my $file	= $url->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			fail("$test: $!");
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		throws_ok {
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} 'RDF::Trine::Error::ParserError', $test;
	}

	note("Positive Evaluation Tests");
	foreach my $test (@eval_good) {
		my ($test_file)	= $model->objects($test, $mf->action);
		my ($res_file)	= $model->objects($test, $mf->result);
		my $url			= URI->new($test_file->uri);
		my $file		= $url->file;
		open( my $fh, '<:encoding(UTF-8)', $file ) or die "$!: $file";
		my $nt			= URI->new($res_file->uri)->file;
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $parser	= RDF::Trine::Parser::Turtle->new();
		my $model	= RDF::Trine::Model->temporary_model;
		my $tbase	= URI->new_abs( $test, $base->uri_value )->as_string;
		my $parsed	= 1;
		try {
			$parser->parse_file_into_model( $tbase, $fh, $model );
		} catch (RDF::Trine::Error $e) {
			$parsed	= 0;
			warn "Failed to parse $file: " . $e->text;
		}
		if ($parsed) {
			compare($model, URI->new($res_file->uri), $base, $test);
		} else {
			fail($test);
		}
	}
	
	note("Negative Evaluation Tests");
	foreach my $test (@eval_bad) {
		my ($test_file)	= $model->objects($test, $mf->action);
		my $file	= URI->new($test_file->uri)->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			fail("$test: $!");
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		throws_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} 'RDF::Trine::Error::ParserError', $test;
	}
}

done_testing();

# sub _SILENCE {
# 	Log::Log4perl->init( {
# 		"log4perl.rootLogger"				=> "FATAL, screen",
# 		"log4perl.appender.screen"			=> "Log::Log4perl::Appender::Screen",
# 		"log4perl.appender.screen.stderr"	=> 1,
# 		"log4perl.appender.screen.layout"	=> 'Log::Log4perl::Layout::SimpleLayout',
# 	} );
# }



sub compare {
	my $model	= shift;
	my $url		= shift;
	my $base	= shift;
	my $name	= shift;
	my $parser	= RDF::Trine::Parser::NTriples->new();
	my $emodel	= RDF::Trine::Model->temporary_model;
	my $tbase	= URI->new_abs( $name, $base->uri_value )->as_string;
	my $file		= $url->file;
	open( my $fh, '<:encoding(UTF-8)', $file );
	try {
		$parser->parse_file_into_model( $tbase, $fh, $emodel );
	};
	
	my $got		= RDF::Trine::Serializer::NTriples::Canonical->new->serialize_model_to_string( $model );
	my $expect	= RDF::Trine::Serializer::NTriples::Canonical->new->serialize_model_to_string( $emodel );
	
	is( $got, $expect, "expected triples: $name" );
}
