use FindBin '$Bin';
use lib "$Bin/lib";


use RDF::Trine qw(iri literal statement);
use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);
use File::Temp qw(tempfile);

use strict;
use Test::More;

plan tests => 2 + Test::RDF::Trine::Store::number_of_tests;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

my $data = Test::RDF::Trine::Store::create_data;
my ($fh, $filename) = tempfile();
my $store	= RDF::Trine::Store::DBI::SQLite->new({
	storetype => 'DBI',
	name      => 'test',
	dsn       => "dbi:SQLite:dbname=$filename",
	username  => '',
	password  => ''
});

note($filename);
isa_ok( $store, 'RDF::Trine::Store::DBI' );
Test::RDF::Trine::Store::all_store_tests($store, $data);
undef $fh;
unlink($filename);

my $hash	= $store->can('_mysql_hash')->('Rhttp://testme.com/');
my $bits	= sprintf("%064b", $hash);
is(substr($bits, 0, 1), '0', 'SQLite hashes do not overflow');
