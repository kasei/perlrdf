#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::file;
use RDF::Query;
use Test::More;
use Scalar::Util qw(blessed);
use RDF::Trine::Iterator qw(smap);

our $debug	= 0;
if ($] < 5.007003) {
	plan skip_all => 'perl >= 5.7.3 required';
	exit;
}

require Encode;
require Data::Dumper;

plan qw(no_plan);
require "t/dawg/earl.pl";

my $PATTERN	= shift(@ARGV);


my @manifests;
my ($bridge, $model)	= new_model( glob( "t/dawg/data-r2/manifest-syntax.ttl" ) );

{
	my $ns		= 'http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#';
	my $inc		= RDF::Query::Node::Resource->new( "${ns}include" );
	my $stream	= $bridge->get_statements( undef, $inc, undef );
	my $statement	= $stream->next();
	
	if ($statement) {
		my $list		= $bridge->object( $statement );
		my $first	= $bridge->new_resource( "http://www.w3.org/1999/02/22-rdf-syntax-ns#first" );
		my $rest	= $bridge->new_resource( "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest" );
		while ($list and $bridge->as_string( $list ) ne '[http://www.w3.org/1999/02/22-rdf-syntax-ns#nil]') {
			my $value			= get_first_obj( $bridge, $list, $first );
			$list				= get_first_obj( $bridge, $list, $rest );
			my $manifest		= $bridge->uri_value( $value );
			
			next unless (defined($manifest));
			$manifest	= relativeize_url( $manifest );
			push(@manifests, $manifest) if (defined($manifest));
		}
	}
	
	warn "Manifest files: " . Data::Dumper::Dumper(\@manifests) if ($debug);
	add_to_model( $bridge, @manifests );
}

my $earl	= init_earl( $bridge );
my $type	= $bridge->new_resource( "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" );
my $pos		= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest" );
my $neg		= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest" );
my $mfname	= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#name" );

{
	print "# Positive Syntax Tests\n";
	my $stream	= $bridge->get_statements( undef, $type, $pos );
	while (my $statement = $stream->next) {
		my $test		= $bridge->subject( $statement );
		no warnings 'uninitialized';
		next unless ($bridge->uri_value( $test ) =~ /$PATTERN/);	# XXX
		my $name		= get_first_literal( $bridge, $test, $mfname );
		my $ok			= positive_syntax_test( $bridge, $test );
		ok( $ok, $name );
		if ($ok) {
			earl_pass_test( $earl, $test );
		} else {
			earl_fail_test( $earl, $test );
			warn RDF::Query->error;
		}
#	} continue {
#		$stream->next;
	}
}

{
	print "# Negative Syntax Tests\n";
	my $stream	= $bridge->get_statements( undef, $type, $neg );
	while (my $statement = $stream->next) {
		my $test		= $bridge->subject( $statement );
		no warnings 'uninitialized';
		next unless ($bridge->uri_value( $test ) =~ /$PATTERN/);	# XXX
		my $name		= get_first_literal( $bridge, $test, $mfname );
		my $ok			= negative_syntax_test( $bridge, $test );
		ok( $ok, $name );
		if ($ok) {
			earl_pass_test( $earl, $test );
		} else {
			earl_fail_test( $earl, $test );
		}
	} continue {
		$stream->next;
	}
}

open( my $fh, '>', 'earl-syntax.ttl' );
print {$fh} earl_output( $earl );
close($fh);


################################################################################


sub positive_syntax_test {
	my $bridge	= shift;
	my $test	= shift;
	my $action	= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action" );
	my $file	= get_first_obj( $bridge, $test, $action );
	my $url		= $bridge->uri_value( $file );
	my $uri		= URI->new( relativeize_url( $url ) );
	my $filename	= $uri->file;
	my $sparql	= do { local($/) = undef; open(my $fh, '<', $filename); <$fh> };
	my $query	= eval { RDF::Query->new( $sparql, undef, undef, 'sparql' ) };
	return 0 if ($@);
	return blessed($query) ? 1 : 0;
}

sub negative_syntax_test {
	my $bridge	= shift;
	my $test	= shift;
	my $action	= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action" );
	my $file	= get_first_obj( $bridge, $test, $action );
	my $url		= $bridge->uri_value( $file );
	my $uri		= URI->new( relativeize_url( $url ) );
	my $filename	= $uri->file;
	my $sparql	= do { local($/) = undef; open(my $fh, '<', $filename); <$fh> };
	my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
	return 1 if ($@);
	warn Data::Dumper::Dumper($query->{parsed}) if (blessed($query));
	warn $query->error if (blessed($query));
	return blessed($query) ? 0 : 1;
}


exit;

######################################################################


sub new_model {
	my @files		= @_;
	my $bridge		= RDF::Query->new_bridge();
	add_to_model( $bridge, file_uris(@files) );
	return ($bridge, $bridge->model);
}

sub add_to_model {
	my $bridge	= shift;
	my @files	= @_;
	
	if ($bridge->isa('RDF::Query::Model::RDFCore')) {
		foreach my $file (@files) {
			Carp::cluck unless ($file);
			if ($file =~ /^http:/) {
				$file	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{t/dawg/data-r2/};
				$file	= 'file://' . File::Spec->rel2abs( $file );
			}
			my $data	= do {
							open(my $fh, '-|', "cwm.py --n3 $file --rdf");
							local($/)	= undef;
							<$fh>
						};
			
			$data		=~ s/^(.*)<rdf:RDF/<rdf:RDF/m;
			$bridge->add_string( $data, $file );
		}
	} else {
		foreach my $file (@files) {
			$bridge->add_uri( $file );
		}
	}
}

sub file_uris {
	my @files	= @_;
	return map { "$_" } map { URI::file->new_abs( $_ ) } @files;
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
		if ($bridge->isa_resource( $node )) {
			return $bridge->uri_value( $node );
		} elsif ($bridge->isa_literal( $node )) {
			return Encode::decode('utf8', $bridge->literal_value( $node ));
		} else {
			return $bridge->blank_identifier( $node );
		}
	} else {
		return;
	}
}


sub get_first_literal {
	my $node	= get_first_obj( @_ );
	return $node ? $bridge->literal_value($node) : undef;
}

sub get_all_literal {
	my @nodes	= get_all_obj( @_ );
	return map { $bridge->literal_value($_) } grep { $bridge->isa_literal($_) } @nodes;
}

sub get_first_uri {
	my $node	= get_first_obj( @_ );
	return $node ? $bridge->uri_value( $node ) : undef;
}

sub get_all_uri {
	my @nodes	= get_all_obj( @_ );
	return map { $bridge->uri_value($_) } grep { defined($_) and $bridge->isa_resource($_) } @nodes;
}

sub get_first_obj {
	my $bridge	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : $bridge->new_resource( $_ ) } @uris;
	foreach my $pred (@preds) {
		my $stream	= $bridge->get_statements( $node, $pred, undef );
		while (my $st = $stream->next) {
			my $node	= $st->object;
			return $node if ($node);
		}
	}
}

sub get_all_obj {
	my $bridge	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : $bridge->new_resource( $_ ) } @uris;
	my @objs;
	
	my @streams;
	foreach my $pred (@preds) {
		push(@streams, $bridge->get_statements( $node, $pred, undef ));
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
		$uri	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{t/dawg/data-r2/};
		$uri	= 'file://' . File::Spec->rel2abs( $uri );
	}
	return $uri;
}


__END__
