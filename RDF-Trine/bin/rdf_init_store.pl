#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use RDF::Trine::Store::DBI;

unless (@ARGV) {
	print <<"END";
USAGE: $0 server-type dbname username password model-name [host]

	server-type can be either 'mysql', 'pg' or 'sqlite'


END
	exit;
}

my $server	= shift;
my $dbname	= shift;
my $user	= shift;
my $pass	= shift;
my $model	= shift;
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

my $store		= RDF::Trine::Store::DBI->new($model, $dsn, $user, $pass);
$store->init;
