#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use File::Slurp;
use LWP::UserAgent;

use RDF::Trine;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement;

unless (@ARGV >= 6) {
	print <<"END";
USAGE: $0 server-type dbname username password model-name file base [host]

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
my $host	= shift;

my $dsn;
if ($server eq 'mysql') {
	$dsn	= "DBI:mysql:database=${dbname}";
} elsif ($server eq 'sqlite') {
	$dsn	= "DBI:SQLite:dbname=${dbname}";
} elsif ($server eq 'pg') {
	$dsn	= "DBI:Pg:dbname=${dbname}";
	if ($host) {
		$dsn	.= ';host=' . $host;
	}
} else {
	warn "Unknown server type: $server\n";
	exit;
}

my $data;
my $store	= RDF::Trine::Store::DBI->new($model, $dsn, $user, $pass);
if ($file =~ qr[^http(s?)://]) {
	my $ua	= LWP::UserAgent->new;
	$ua->agent( "RDF::Trine/${RDF::Trine::VERSION}" );
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

# my $format	= 'guess';
# my $baseuri		= RDF::Redland::URI->new( $base );
# my $basenode	= RDF::Trine::Node::Resource->new( $base );
# my $parser		= RDF::Redland::Parser->new( $format );
# my $stream		= $parser->parse_string_as_stream( $data, $baseuri );
# while ($stream and !$stream->end) {
# 	my $statement	= $stream->current;
# 	my $stmt		= RDF::Trine::Statement->from_redland( $statement );
# 	$store->add_statement( $stmt, $basenode );
# 	$stream->next;
# }
# 

my $pclass	= RDF::Trine::Parser->guess_parser_by_filename( $file );
my $parser	= $pclass->new();
my $m		= RDF::Trine::Model->new( $store );
$parser->parse_into_model( $base, $data, $m );
