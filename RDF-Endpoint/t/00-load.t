#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'RDF::Endpoint' );
}

diag( "Testing RDF::LinkedData $RDF::Endpoint::VERSION, Perl $], $^X" );
