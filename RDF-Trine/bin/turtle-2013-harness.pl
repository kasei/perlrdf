use utf8;
use strict;
use FindBin qw($Bin);
use File::Glob qw(bsd_glob);
use File::Spec;
use Data::Dumper;
use Scalar::Util qw(blessed);
use RDF::Trine qw(iri literal);
use RDF::Trine::Namespace qw(rdf);
use RDF::EARL;
use URI::file;
use TryCatch;

sub throws_ok (&;$) {	## no critic
	my ( $coderef, $description ) = @_;
	eval { $coderef->() };
	return ($@) ? 1 : 0;
}

sub lives_ok (&;$) {	## no critic
	my ( $coderef, $description ) = @_;
	eval { $coderef->() };
	return ($@) ? 0 : 1;
}


my $earl	= RDF::EARL->new( subject => 'http://kasei.us/code/rdf-trine/#project', assertor => 'http://kasei.us/about/foaf.xrdf#greg' );
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
	foreach my $t (@syntax_good) {
		my ($test_file)	= $model->objects($t, $mf->action);
		my $file	= URI->new($test_file->uri)->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			$earl->fail(test_uri($t));
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $ok	= lives_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} $test;
	
		if ($ok) {
			$earl->pass(test_uri($t));
		} else {
			$earl->fail(test_uri($t));
		}
	}

	note("Negative Syntax Tests");
	foreach my $t (@syntax_bad) {
		my ($test_file)	= $model->objects($t, $mf->action);
		my $url		= URI->new($test_file->uri);
		my $file	= $url->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			$earl->fail(test_uri($t));
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $ok	= throws_ok {
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} 'RDF::Trine::Error::ParserError';
	
		if ($ok) {
			$earl->pass(test_uri($t));
		} else {
			$earl->fail(test_uri($t));
		}
	}

	note("Positive Evaluation Tests");
	foreach my $t (@eval_good) {
		my ($test_file)	= $model->objects($t, $mf->action);
		my ($res_file)	= $model->objects($t, $mf->result);
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
	# 		warn "Failed to parse $file: " . $err->text;
		}
		if ($parsed) {
			my $ok	= compare($model, URI->new($res_file->uri), $base, $test);
			if ($ok) {
				$earl->pass(test_uri($t));
			} else {
				$earl->fail(test_uri($t));
			}
		} else {
			$earl->fail(test_uri($t));
		}
	}
	
	note("Negative Evaluation Tests");
	foreach my $t (@eval_bad) {
		my ($test_file)	= $model->objects($t, $mf->action);
		my $file	= URI->new($test_file->uri)->file;
		my $data	= eval { do { open( my $fh, '<', $file ) or die $!; local($/) = undef; <$fh> } };
		if ($@) {
			$earl->fail(test_uri($t));
			next;
		}
		my (undef, undef, $test)	= File::Spec->splitpath( $file );
		my $ok	= throws_ok {
			my $url	= 'file://' . $file;
			my $parser	= RDF::Trine::Parser::Turtle->new();
			$parser->parse( $url, $data );
		} 'RDF::Trine::Error::ParserError';
	
		if ($ok) {
			$earl->pass(test_uri($t));
		} else {
			$earl->fail(test_uri($t));
		}
	}
}

my $model	= $earl->model;
my $p		= RDF::Trine::Parser->new('turtle');
$p->parse_into_model( undef, <<'END', $model );
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix doap: <http://usefulinc.com/ns/doap#> .
<http://kasei.us/about/foaf.xrdf#greg> a foaf:Person ;
	foaf:name "Gregory Todd Williams" ;
	foaf:depiction <http://kasei.us/images/greg.png> ;
	foaf:homepage <http://kasei.us/> ;
	foaf:mbox <mailto:greg@evilfunhouse.com> ;
	foaf:mbox_sha1sum "19fc9d0234848371668cf10a1b71ac9bd4236806", "25c5f4f21afaedf113d92ac7c8591178ad9c03fa", "41cc0788a269f33e52fc99080a970278c845ee5f", "4e6174e69033cfce87eecf828a99f8ce2c0c2fa6", "6187ab068a6dd0887b8220b02075d68c96152e17", "7d1958feafea26921db0c51e6d0eb89f716f8c02", "8df861ee96107c82e516191816954050ed376d79", "9d179d12b032b4689cf5dd1ffaf237c3e007c919", "dde73ef37a2fc05d41b6a48d9670cd094baf7fb4", "f3c455a88761f83ba243b2653e6042de71fdd149", "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ;
	.

<http://kasei.us/code/rdf-trine/#project>
	a <http://usefulinc.com/ns/doap#Project> ;
	<http://usefulinc.com/ns/doap#name> "RDF::Trine" ;
	<http://usefulinc.com/ns/doap#download-mirror> <http://kasei.us/code/rdf-trine/> ;
	<http://usefulinc.com/ns/doap#download-page> <http://search.cpan.org/dist/RDF-Trine/> ;
	<http://usefulinc.com/ns/doap#programming-language> "perl" ;
	<http://usefulinc.com/ns/doap#implements> <http://www.w3.org/TR/turtle/> ;
	<http://usefulinc.com/ns/doap#developer> <http://kasei.us/about/foaf.xrdf#greg> ;
	.
END
my $map		= RDF::Trine::NamespaceMap->new( {
				earl	=> iri('http://www.w3.org/ns/earl#'),
				rt		=> iri('http://kasei.us/code/rdf-trine/#'),
				doap	=> iri('http://usefulinc.com/ns/doap#'),
				foaf	=> iri('http://xmlns.com/foaf/0.1/'),
				ttlc	=> iri('https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-turtle/coverage/tests/manifest.ttl#'),
				ttl		=> iri('https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-turtle/tests-ttl/manifest.ttl#'),
			} );
warn "EARL model has " . $model->size . " triples\n";
my $s		= RDF::Trine::Serializer->new('turtle', namespaces => $map);
$s->serialize_model_to_file( \*STDOUT, $model );

sub test_uri {
	my $test	= shift;
	my $uri		= blessed($test) ? $test->uri_value : $test;
	$uri		=~ s{^.*/manifest.ttl}{http://www.w3.org/2013/TurtleTests/manifest.ttl};
	return $uri;
}

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
	} catch ($err) {
# 		warn "Failed to parse $file: " . $err->text . "(test $name)";
	}
	
	my $got		= RDF::Trine::Serializer::NTriples::Canonical->new->serialize_model_to_string( $model );
	my $expect	= RDF::Trine::Serializer::NTriples::Canonical->new->serialize_model_to_string( $emodel );
	
	return ($got eq $expect);
}

sub note {
	my $msg	= shift;
#  	warn "########## $msg";
}
