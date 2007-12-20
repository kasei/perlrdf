#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Slurp;
use RDF::Redland;
use LWP::UserAgent;
use RDF::Store::DBI;
use RDF::Trice::Statement;

unless (@ARGV >= 6) {
	print <<"END";
USAGE: $0 server-type dbname username password model-name file base

	server-type can be either 'mysql' or 'sqlite'


END
	exit;
}

my $server	= shift;
my $dbname	= shift;
my $user	= shift;
my $pass	= shift;
my $model	= shift;
my $file	= shift;
my $base	= shift;

my $dsn;
if ($server eq 'mysql') {
	$dsn	= "DBI:mysql:database=${dbname}";
} elsif ($server eq 'sqlite') {
	$dsn	= "DBI:sqlite:database=${dbname}";
} else {
	warn "Unknown server type: $server\n";
	exit;
}

my $data;
my $store	= RDF::Store::DBI->new($model, $dsn, $user, $pass);
if ($file =~ qr[^http(s?)://]) {
	my $ua	= LWP::UserAgent->new;
	$ua->agent( "RDF::Trice/${RDF::Trice::VERSION}" );
	$ua->default_header( 'Accept' => 'application/turtle,application/x-turtle,application/rdf+xml' );
	my $resp	= $ua->get( $file );
	if ($resp->is_success) {
		$data		= $resp->content;
	} else {
		die $resp->status_line;
	}
	
	unless ($base) {
		$base		= $file;
	}
} else {
	$data	= read_file( $file );
	unless ($base) {
		my $abs	= File::Spec->rel2abs( $file );
		$base	= 'file://' . $abs;
	}
}

my $format	= 'guess';
my $baseuri		= RDF::Redland::URI->new( $base );
my $basenode	= RDF::Trice::Node::Resource->new( $base );
my $parser		= RDF::Redland::Parser->new( $format );
my $stream		= $parser->parse_string_as_stream( $data, $baseuri );
while ($stream and !$stream->end) {
	my $statement	= $stream->current;
	my $stmt		= RDF::Trice::Statement->from_redland( $statement );
	$store->add_statement( $stmt, $basenode );
	$stream->next;
}


