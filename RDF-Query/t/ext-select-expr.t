#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my $tests	= 7;
my @models	= test_models( qw(data/greenwich.rdf data/about.xrdf) );
plan tests => 1 + ($tests * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	{
		print "# select expression (node plus literal)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT (?lat AS ?latitude)
			WHERE {
				?point a geo:Point ;
					foaf:name "Royal Observatory Greenwich" ;
					geo:lat ?lat ;
					geo:long ?long
			}
END
		my $count	= 0;
		my $stream	= $query->execute( $model );
		while (my $row = $stream->next) {
			my ($lat)	= @{ $row }{qw(latitude)};
			is( $lat->literal_value, '51.477222', 'AS for alpha conversion' );
		} continue { ++$count };
		is( $count, 1, 'expecting one statement in model' );
	}

	{
		print "# select expression (node plus literal)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT ?lat (?long + 1.0 AS ?long_off)
			WHERE {
				?point a geo:Point ;
					foaf:name "Royal Observatory Greenwich" ;
					geo:lat ?lat ;
					geo:long ?long
			}
END
		my $count	= 0;
		my $stream	= $query->execute( $model );
		while (my $row = $stream->next) {
			my ($lat, $long)	= @{ $row }{qw(lat long_off)};
			is( $lat->literal_value, '51.477222', 'existing latitude' );
			cmp_ok( $long->literal_value, '==', 1, 'modified longitude' );
		} continue { ++$count };
		is( $count, 1, 'expecting one statement in model' );
	}

	eval "use Geo::Distance 0.09;";
	my $GEO_DISTANCE_LOADED	= ($@) ? 0 : 1;
	SKIP: {
		skip( "Need Geo::Distance 0.09 or higher to run these tests.", 2 ) unless ($GEO_DISTANCE_LOADED);
		print "# select expression (function)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX ldodds: <java:com.ldodds.sparql.>
			SELECT ?image ?name (ldodds:Distance(?lat, ?long, 41.849331, -71.392) AS ?dist)
			WHERE {
					?image a foaf:Image ;
						dcterms:spatial [
							foaf:name ?name ;
							geo:lat ?lat ;
							geo:long ?long ;
						] .
			}
			ORDER BY ldodds:Distance(?lat, ?long, 41.849331, -71.392)
			LIMIT 1
END
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next()) {
			my ($image, $pname, $pdist)	= @{ $row }{qw(image name dist)};
			my $name	= $pname->literal_value;
			my $dist	= $pdist->literal_value;
			like( $dist, qr/^0[.]0577\d*$/, "distance $name" );
			$count++;
		}
		is( $count, 1, "ldodds:Distance: 1 objects found" );
	}
}
