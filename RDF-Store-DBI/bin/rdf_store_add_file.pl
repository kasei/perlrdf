#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Slurp;
use RDF::Redland;
use RDF::Store::DBI;
use LWP::Simple qw(get);
use RDF::Query::Algebra::Triple;

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
	$data		= get( $file );
	unless ($base) {
		$base		= $file;
	}
} else {
	my $data	= read_file( $file );
	unless ($base) {
		my $abs	= File::Spec->rel2abs( $file );
		$base	= 'file://' . $abs;
	}
}
my $format	= 'guess';

my $baseuri		= RDF::Redland::URI->new( $base );
my $basenode	= RDF::Query::Node::Resource->new( $base );
my $parser		= RDF::Redland::Parser->new( $format );
my $stream		= $parser->parse_string_as_stream( $data, $baseuri );
while ($stream and !$stream->end) {
	my $statement	= $stream->current;
	my $stmt		= RDF::Query::Algebra::Triple->from_redland( $statement );
	$store->add_statement( $stmt, $basenode );
	$stream->next;
}


