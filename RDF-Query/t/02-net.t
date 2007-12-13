#!/usr/bin/perl
use strict;
use warnings;
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

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	
	my @model	= ref($model) ? $model : ();
	
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
	my @results	= $query->execute( @model );
	is( scalar(@results), 1, 'Got one result' );
	isa_ok( $results[0], 'HASH' );
	is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
	ok( $query->bridge->isa_resource( $results[0]{page} ), 'Resource' );
	is( $query->bridge->uri_value( $results[0]{page} ), 'http://kasei.us/', 'Got homepage url' );
}


# SKIP: {
# 	eval "use RDF::Query::Model::RDFCore; use RDF::Core; use RDF::Core::Storage::Memory; use RDF::Core::Model;";
# 	if ($@) {
# 		skip "Failed to load RDF::Core", 5;
# 	} else {
# 		$has_backend	= 1;
# 	}
# 	
# 	print "# RDF::Core\n";
# 	my $storage	= new RDF::Core::Storage::Memory;
# 	my $model	= new RDF::Core::Model (Storage => $storage);
# 	
# 	my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
# 		SELECT
# 			?page
# 		FROM
# 			<http://homepage.mac.com/samofool/rdf-query/test-data/foaf.rdf>
# 		WHERE
# 			(?person foaf:name "Gregory Todd Williams")
# 			(?person foaf:homepage ?page)
# 		USING
# 			foaf FOR <http://xmlns.com/foaf/0.1/>
# END
# 	my @results	= $query->execute( $model );
# 	is( scalar(@results), 1, 'Got one result' );
# 	isa_ok( $results[0], 'ARRAY' );
# 	is( scalar(@{$results[0]}), 1, 'Got one field' );
# 	ok( $query->bridge->isa_resource( $results[0][0] ), 'Resource' );
# 	is( $query->bridge->uri_value( $results[0][0] ), 'http://kasei.us/', 'Got homepage url' );
# }
# 
# SKIP: {
# 	skip "No backend available for execute() call with no query", 5 unless ($has_backend);
# 	
# 	print "# No model\n";
# 	my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
# 		SELECT	?page
# 		FROM	<http://homepage.mac.com/samofool/rdf-query/test-data/foaf.rdf>
# 		WHERE {
# 				?person foaf:name "Gregory Todd Williams" ;
# 					foaf:homepage ?page .
# 		}
# END
# 	my @results	= $query->execute();
# 	is( scalar(@results), 1, 'Got one result' );
# 	isa_ok( $results[0], 'ARRAY' );
# 	is( scalar(@{$results[0]}), 1, 'Got one field' );
# 	ok( $query->bridge->isa_resource( $results[0][0] ), 'Resource' );
# 	is( $query->bridge->uri_value( $results[0][0] ), 'http://kasei.us/', 'Got homepage url' );
# }
