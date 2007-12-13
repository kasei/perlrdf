#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 11);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT ?person ?homepage
			WHERE {
					?person foaf:name "Gregory Todd Williams" .
					?person foaf:homepage ?homepage .
					FILTER ( REGEX(STR(?homepage), "kasei") ) .
			}
END
		my ($person, $homepage)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_resource( $person ), 'Resource with regex match' );
		is( $bridge->uri_value( $person ), 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT ?person ?homepage
			WHERE {
					?person foaf:name "Gregory Todd Williams" .
					?person foaf:homepage ?homepage .
					FILTER ( REGEX(STR(?homepage), "not_in_here") ) .
			}
END
		my ($person, $homepage)	= $query->get( $model );
		my $bridge	= $query->bridge;
		is( $person, undef, 'no result with regex match' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
					?point ?lat ?lon
			WHERE
					(<http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg> dcterms:spatial ?point)
					(?point geo:lat ?lat)
					(?point geo:long ?lon)
			AND
					?lat > 52.97,
					?lat < 53.036526
			USING
					rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
					foaf FOR <http://xmlns.com/foaf/0.1/>,
					dcterms FOR <http://purl.org/dc/terms/>,
					geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
		my ($point, $lat, $lon)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_node( $point ), 'Point isa Node' );
		cmp_ok( abs( $bridge->literal_value( $lat ) - 52.97277 ), '<', 0.001, 'latitude' );
		cmp_ok( abs( $bridge->literal_value( $lon ) + 9.430733 ), '<', 0.001, 'longitude' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
					?point ?lat ?lon
			WHERE
					(<http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg> dcterms:spatial ?point)
					(?point geo:lat ?lat)
					(?point geo:long ?lon)
			AND
					?lat > 52,
					?lat < 53
			USING
					rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
					foaf FOR <http://xmlns.com/foaf/0.1/>,
					dcterms FOR <http://purl.org/dc/terms/>,
					geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
		my ($point, $lat, $lon)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_node( $point ), 'Point isa Node' );
		cmp_ok( abs( $bridge->literal_value( $lat ) - 52.97277 ), '<', 0.001, 'latitude' );
		cmp_ok( abs( $bridge->literal_value( $lon ) + 9.430733 ), '<', 0.001, 'longitude' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
					?image ?point ?lat
			WHERE
					(?point geo:lat ?lat)
					(?image dcterms:spatial ?point)
			AND
					?lat > 52.972,
					?lat < 53
			USING
					rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
					foaf FOR <http://xmlns.com/foaf/0.1/>,
					dcterms FOR <http://purl.org/dc/terms/>,
					geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
		my ($image, $point, $lat)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_resource( $image ), 'Image isa Resource' );
		is( $bridge->uri_value( $image ), 'http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg', 'Image url' );
	}
}

__END__
