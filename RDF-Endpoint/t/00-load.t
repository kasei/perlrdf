#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'RDF::Endpoint' );
}

diag( "Testing RDF::Endpoint $RDF::Endpoint::VERSION, Perl $], $^X" );
