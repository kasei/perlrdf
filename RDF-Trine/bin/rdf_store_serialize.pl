#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use File::Slurp;
use LWP::UserAgent;
use Data::Dumper;

use RDF::Trine;
use RDF::Trine::Model;
use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement;

unless (@ARGV >= 4) {
	print <<"END";
USAGE: $0 server-type dbname username password model-name [host]

	server-type can be either 'mysql' or 'sqlite'


END
	exit;
}

my $server		= shift;
my $dbname		= shift;
my $user		= shift;
my $pass		= shift;
my $modelname	= shift;
my $host		= shift;

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

my $store	= RDF::Trine::Store::DBI->new($modelname, $dsn, $user, $pass);
my $model	= RDF::Trine::Model->new($store);

my $serializer	= RDF::Trine::Serializer::NTriples->new();
$serializer->serialize_model_to_file( \*STDOUT, $model );

if (0) {
	my $iter	= $store->get_statements();
	
	while (my $s = $iter->next) {
		print $s->as_string . "\n";
	}
}
