#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
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
		my $query	= new RDF::Query ( <<"END" );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT ?point ?lat ?lon
			WHERE {
				<http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg> dcterms:spatial ?point .
				?point geo:lat ?lat ; geo:long ?lon .
				FILTER ( xsd:float(?lat) > 52.97 && xsd:float(?lat) < 53.036526 )
			}
END
		my ($point, $lat, $lon)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_node( $point ), 'Point isa Node' );
		cmp_ok( abs( $lat->numeric_value - 52.97277 ), '<', 0.001, 'latitude' );
		cmp_ok( abs( $lon->literal_value + 9.430733 ), '<', 0.001, 'longitude' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT ?point ?lat ?lon
			WHERE {
				<http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg> dcterms:spatial ?point .
				?point geo:lat ?lat ; geo:long ?lon .
				FILTER( xsd:float(?lat) > 52 && xsd:float(?lat) < 53 )
			}
END
		warn RDF::Query->error unless ($query);
		my ($point, $lat, $lon)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_node( $point ), 'Point isa Node' );
		cmp_ok( abs( $bridge->literal_value( $lat ) - 52.97277 ), '<', 0.001, 'latitude' );
		cmp_ok( abs( $bridge->literal_value( $lon ) + 9.430733 ), '<', 0.001, 'longitude' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT ?image ?lat ?lon
			WHERE {
				?image dcterms:spatial [ geo:lat ?lat ] .
				FILTER( xsd:float(?lat) > 52.972 ) .
				FILTER( xsd:float(?lat) < 53 ) .
			}
END
		my ($image, $point, $lat)	= $query->get( $model );
		my $bridge	= $query->bridge;
		ok( $bridge->isa_resource( $image ), 'Image isa Resource' );
		is( $bridge->uri_value( $image ), 'http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg', 'Image url' );
	}
}

__END__
