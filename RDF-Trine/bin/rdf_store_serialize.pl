#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use File::Slurp;
use RDF::Redland;
use LWP::UserAgent;
use Data::Dumper;

use RDF::Trine;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement;

unless (@ARGV >= 4) {
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

my $data;
my $store	= RDF::Trine::Store::DBI->new($model, $dsn, $user, $pass);
my $iter	= $store->get_statements();

while (my $s = $iter->next) {
	print $s->as_sparql . "\n";
}


