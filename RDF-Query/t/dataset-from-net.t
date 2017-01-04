#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files;
my @models	= test_models( @files );

eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading URLs";
	return;
} elsif ($ENV{RDFQUERY_NETWORK_TESTS}) {
	plan tests => 1 + (5 * scalar(@models));
} else {
	plan skip_all => 'No network. Set RDFQUERY_NETWORK_TESTS to run these tests.';
	return;
}

my $loaded	= use_ok( 'RDF::Query' );
BAIL_OUT( "RDF::Query not loaded" ) unless ($loaded);

my $has_backend	= 0;

{
	my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT
			?page
		FROM
			<http://kasei.us/code/rdf-query/test-data/foaf.rdf>
		WHERE
			(?person foaf:name "Gregory Todd Williams")
			(?person foaf:homepage ?page)
		USING
			foaf FOR <http://xmlns.com/foaf/0.1/>
END
	foreach my $model (@models) {
		print "\n#################################\n";
		print "### Using model: $model\n";
		
		my @model	= ref($model) ? $model : ();
		
		my @results	= $query->execute( @model );
		is( scalar(@results), 1, 'Got one result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{page}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{page}->uri_value, 'http://kasei.us/', 'Got homepage url' );
	}
}
