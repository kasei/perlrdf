#!/usr/bin/perl

use strict;
use warnings;
use RDF::Store::DBI;

unless (@ARGV) {
	print <<"END";
USAGE: $0 server-type dbname username password model-name

	server-type can be either 'mysql' or 'sqlite'


END
	exit;
}

my $server	= shift;
my $dbname	= shift;
my $user	= shift;
my $pass	= shift;
my $model	= shift;

my $dsn;
if ($server eq 'mysql') {
	$dsn	= "DBI:mysql:database=${dbname}";
} elsif ($server eq 'sqlite') {
	$dsn	= "DBI:sqlite:database=${dbname}";
} else {
	warn "Unknown server type: $server\n";
	exit;
}

my $store		= RDF::Store::DBI->new($model, $dsn, $user, $pass);
$store->init;
