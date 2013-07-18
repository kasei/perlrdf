use FindBin '$Bin';
use lib "$Bin/lib";


use RDF::Trine qw(iri literal statement);
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);

use strict;
use Test::More;

use Module::Load::Conditional qw[can_load];

unless (can_load( modules => { 'DBD::Pg' => 0 })) {
  plan skip_all => "DBD::Pg must be installed for Postgres tests";
}


unless (
		exists $ENV{RDFTRINE_STORE_PG_DATABASE} and
		exists $ENV{RDFTRINE_STORE_PG_MODEL}) {
	plan skip_all => "Set the Pg environment variables to run these tests at least RDFTRINE_STORE_PG_DATABASE and RDFTRINE_STORE_PG_MODEL)";
}

my $db		= $ENV{RDFTRINE_STORE_PG_DATABASE};
my $host	= $ENV{RDFTRINE_STORE_PG_HOST};
my $port	= $ENV{RDFTRINE_STORE_PG_PORT};
my $user	= $ENV{RDFTRINE_STORE_PG_USER};
my $pass	= $ENV{RDFTRINE_STORE_PG_PASSWORD}; 
my $model	= $ENV{RDFTRINE_STORE_PG_MODEL};

plan tests => 4 + Test::RDF::Trine::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

my $dsn	= "DBI:Pg:database=$db";
$dsn	.= ";host=$host" if (defined($host));
$dsn	.= ";port=$port" if (defined($port));

persist_test($dsn, $user, $pass, $model);

my $data = Test::RDF::Trine::Store::create_data;

my $dbh	= DBI->connect( $dsn, $user, $pass );
my $store	= RDF::Trine::Store::DBI::Pg->new( $model, $dbh );
isa_ok( $store, 'RDF::Trine::Store::DBI::Pg' );

Test::RDF::Trine::Store::all_store_tests($store, $data);


sub new_store {
	my $dsn		= shift;
	my $user	= shift;
	my $pass	= shift;
	my $model	= shift;
	my $dbh	= DBI->connect( $dsn, $user, $pass );
	if ((! $dbh) || ($dbh->err)) {
		diag 'Connection to database failed';
		diag 'You may have to set one or more of RDFTRINE_STORE_PG_HOST, RDFTRINE_STORE_PG_PORT, RDFTRINE_STORE_PG_USER, RDFTRINE_STORE_PG_PASSWORD';
	}
	my $store	= RDF::Trine::Store::DBI::Pg->new( $model, $dbh );
	return $store;
}

sub persist_test {
	note " persistence tests";
	my $dsn		= shift;
	my $user	= shift;
	my $pass	= shift;
	my $model	= shift;
	my $st		= statement(
					iri('http://example.org/'),
					iri('http://purl.org/dc/elements/1.1/title'),
					literal('test')
				);
	{
		my $store	= new_store( $dsn, $user, $pass, $model );
		$store->add_statement( $st );
		is( $store->count_statements, 1, 'insert statement' );
	}
	{
		my $store	= new_store( $dsn, $user, $pass, $model );
		is( $store->count_statements, 1, 'statement persists across dbh connections' );
		$store->remove_statement( $st );
		is( $store->count_statements, 0, 'cleaned up persistent statement' );
	}
}
