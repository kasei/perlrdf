#!/usr/bin/perl
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
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_NO_NETWORK}) {
	plan tests => 1 + (5 * scalar(@models));
} else {
	plan skip_all => 'No network. Unset RDFQUERY_NO_NETWORK to run these tests.';
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
			<http://homepage.mac.com/samofool/rdf-query/test-data/foaf.rdf>
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
		ok( $query->bridge->isa_resource( $results[0]{page} ), 'Resource' );
		is( $query->bridge->uri_value( $results[0]{page} ), 'http://kasei.us/', 'Got homepage url' );
	}
}
