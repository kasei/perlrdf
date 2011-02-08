#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::file;
use RDF::Query;
use Test::More;
use Scalar::Util qw(blessed);
use RDF::Trine::Iterator qw(smap);
use RDF::Query::Node qw(iri);
use LWP::Simple;

our $debug	= 0;
if ($] < 5.007003) {
	plan skip_all => 'perl >= 5.7.3 required';
	exit;
}

require Encode;
require Data::Dumper;

plan qw(no_plan);
require "xt/dawg/earl.pl";

my $PATTERN	= shift(@ARGV);


my @manifests;
my $model	= new_model( map { glob( "xt/dawg11/$_/manifest.ttl" ) }
	qw(
		syntax-query
		syntax-update-1
		syntax-update-2
	) );

my $earl		= init_earl( $model );
my $type		= iri( "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" );
my $pos_query	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest11" );
my $pos_update	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveUpdateSyntaxTest11" );
my $neg_query	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest11" );
my $neg_update	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeUpdateSyntaxTest11" );
my $mfname		= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#name" );
my $mfaction	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action" );

{
	print "# Positive Syntax Tests\n";
	my @tests;
	push(@tests, $model->subjects( $type, $pos_query ));
	push(@tests, $model->subjects( $type, $pos_update ));
	foreach my $test (@tests) {
# 	my $stream	= $model->get_statements( undef, $type, $pos );
# 	while (my $statement = $stream->next) {
# 		my $test		= $statement->subject;
		no warnings 'uninitialized';
		next unless ($test->uri_value =~ /$PATTERN/);	# XXX
		my $name		= get_first_literal( $model, $test, $mfname );
		my $ok			= positive_syntax_test( $model, $test );
		ok( $ok, $name );
		if ($ok) {
			earl_pass_test( $earl, globalize_uri_filename($test) );
		} else {
			earl_fail_test( $earl, globalize_uri_filename($test) );
			warn RDF::Query->error;
		}
#	} continue {
#		$stream->next;
	}
}

{
	print "# Negative Syntax Tests\n";
	my @tests;
	push(@tests, $model->subjects( $type, $neg_query ));
	push(@tests, $model->subjects( $type, $neg_update ));
	foreach my $test (@tests) {
#	my $stream	= $model->get_statements( undef, $type, $neg );
#	while (my $statement = $stream->next) {
#		my $test		= $statement->subject;
		no warnings 'uninitialized';
		next unless ($test->uri_value =~ /$PATTERN/);	# XXX
		my $name		= get_first_literal( $model, $test, $mfname );
		my $ok			= negative_syntax_test( $model, $test );
		ok( $ok, $name );
		if ($ok) {
			earl_pass_test( $earl, globalize_uri_filename($test) );
		} else {
			earl_fail_test( $earl, globalize_uri_filename($test) );
		}
# 	} continue {
# 		$stream->next;
	}
}

open( my $fh, '>', 'earl-syntax-11.ttl' );
print {$fh} earl_output( $earl );
close($fh);


################################################################################


sub positive_syntax_test {
	my $model	= shift;
	my $test	= shift;
	my $action	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action" );
	my $file	= get_first_obj( $model, $test, $action );
	my $url		= $file->uri_value;
	my $uri		= URI->new( relativeize_url( $url ) );
	my $filename	= localize_uri_filename( $uri->file );
	my $sparql	= do { local($/) = undef; open(my $fh, '<', $filename); <$fh> };
	my $query	= eval { RDF::Query->new( $sparql, { lang => 'sparql11', update => 1 } ) };
	return 0 if ($@);
	return blessed($query) ? 1 : 0;
}

sub negative_syntax_test {
	my $model	= shift;
	my $test	= shift;
	my $action	= iri( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action" );
	my $file	= get_first_obj( $model, $test, $action );
	my $url		= $file->uri_value;
	my $uri		= URI->new( relativeize_url( $url ) );
	my $filename	= $uri->file;
	my $sparql	= do { local($/) = undef; open(my $fh, '<', $filename); <$fh> };
	my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql11' );
	return 1 if ($@);
	warn 'Test expected failure but successfully parsed: ' . Data::Dumper::Dumper($query->{parsed}) if (blessed($query));
	warn $query->error if (blessed($query));
	return blessed($query) ? 0 : 1;
}


exit;

######################################################################


sub new_model {
	my @files		= @_;
	my $model		= RDF::Trine::Model->temporary_model;
	add_to_model( $model, file_uris(@files) );
	return ($model);
}

sub add_to_model {
	my $model	= shift;
	my @files	= @_;
	foreach my $file (@files) {
		my $pclass	= RDF::Trine::Parser->guess_parser_by_filename( $file );
		my $parser	= $pclass->new();
		my $rdf		= get($file);
		$parser->parse_into_model( $file, $rdf, $model );
	}
}

sub localize_uri_filename {
	my $uri	= shift;
	$uri	=~ s{^http://www.w3.org/2009/sparql/docs/tests/data-sparql11/}{xt/dawg11/};
	return $uri;
}

sub globalize_uri_filename {
	my $uri	= shift;
	$uri	= $uri->uri_value;
	$uri	=~ s{^.*xt/dawg11/}{http://www.w3.org/2009/sparql/docs/tests/data-sparql11/};
	return RDF::Trine::Node::Resource->new($uri);
}

sub file_uris {
	my @files	= @_;
	my @uris	= map { "$_" } map { URI::file->new_abs( $_ ) } @files;
	return @uris;
}

######################################################################


sub get_first_as_string  {
	my $node	= get_first_obj( @_ );
	return unless $node;
	return node_as_string( $node );
}

sub node_as_string {
	my $node	= shift;
	if ($node) {
		no warnings 'once';
		if ($node->isa('RDF::Trine::Node::Resource')) {
			return $node->uri_value;
		} elsif ($node->isa_literal) {
			return Encode::decode('utf8', $node->literal_value);
		} else {
			return $node->blank_identifier;
		}
	} else {
		return;
	}
}


sub get_first_literal {
	my $node	= get_first_obj( @_ );
	return $node ? $node->literal_value : undef;
}

sub get_all_literal {
	my @nodes	= get_all_obj( @_ );
	return map { $_->literal_value } grep { $_->isa('RDF::Trine::Node::Literal') } @nodes;
}

sub get_first_uri {
	my $node	= get_first_obj( @_ );
	return $node ? $node->uri_value : undef;
}

sub get_all_uri {
	my @nodes	= get_all_obj( @_ );
	return map { $_->uri_value } grep { defined($_) and $_->isa('RDF::Trine::Node::Resource') } @nodes;
}

sub get_first_obj {
	my $model	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : iri( $_ ) } @uris;
	foreach my $pred (@preds) {
		my $stream	= $model->get_statements( $node, $pred, undef );
		while (my $st = $stream->next) {
			my $node	= $st->object;
			return $node if ($node);
		}
	}
}

sub get_all_obj {
	my $model	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : iri( $_ ) } @uris;
	my @objs;
	
	my @streams;
	foreach my $pred (@preds) {
		push(@streams, $model->get_statements( $node, $pred, undef ));
	}
	my $stream	= shift(@streams);
	while (@streams) {
		$stream	= $stream->concat( shift(@streams) );
	}
	return map { $_->object } $stream->get_all();
}

sub relativeize_url {
	my $uri	= shift;
	if ($uri =~ /^http:/) {
		$uri	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{xt/dawg/data-r2/};
		$uri	= 'file://' . File::Spec->rel2abs( $uri );
	}
	return $uri;
}


__END__
