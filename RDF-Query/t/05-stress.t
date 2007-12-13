#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use RDF::Query;

if ($ENV{RDFQUERY_BIGTEST}) {
	plan qw(no_plan);
} else {
	plan skip_all => 'Developer tests. Set RDFQUERY_BIGTEST to run these tests.';
	return;
}

my @models;

eval "require Kasei::RDF::Common;";
if (not $@ and not $ENV{RDFQUERY_NO_REDLAND_MYSQL}) {
	Kasei::RDF::Common->import('mysql_model');
	my $model	= mysql_model();
	push(@models, $model);
}

eval "use RDF::Core::Storage::Mysql; use RDF::Core::Model; use Kasei::Common;";
if (not $@ and not $ENV{RDFQUERY_NO_RDFCORE}) {
	my $dbh	= Kasei::Common::dbh();
	my $storage	= new RDF::Core::Storage::Mysql ( dbh => $dbh, Model => 'db1' );
	my $model = new RDF::Core::Model (Storage => $storage);
	push(@models, $model);
}

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		print "# FILTER rage test\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		SELECT	?image ?point ?lat
		WHERE	{
					?point geo:lat ?lat .
					?image ?pred ?point .
					FILTER(	(?pred = <http://purl.org/dc/terms/spatial> || ?pred = <http://xmlns.com/foaf/0.1/based_near>)
						&&	?lat > 52
						&&	?lat < 53
					) .
				}
END
		my ($image, $point, $lat)	= $query->get( $model );
		ok($query->bridge->isa_resource( $image ), 'image is resource');
		ok( $query->bridge->isa_resource($image), $image ? $query->bridge->as_string($image) : undef );
		my $latv	= ($lat) ? $query->bridge->literal_value( $lat ) : undef;
		cmp_ok( $latv, '>', 52, 'lat: ' . $latv );
		cmp_ok( $latv, '<', 53, 'lat: ' . $latv );
	}
	
	{
		print "# lots of points!\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; foaf:name ?name ]
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'CODE', 'stream' );
		my $count;
		while (my $row = $stream->()) {
			my ($node)	= @{ $row };
			my $name	= $query->bridge->as_string( $node );
			ok( $name, $name );
		} continue { last if ++$count >= 100 };
	}
	
	{
		print "# foaf:Person ORDER BY name\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	DISTINCT ?p ?name
			WHERE	{
						?p a foaf:Person; foaf:name ?name
					}
			ORDER BY ?name
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'CODE', 'stream' );
		my ($count, $last);
		while (my $row = $stream->()) {
			my ($p, $node)	= @{ $row };
			my $name	= $query->bridge->as_string( $node );
			if (defined($last)) {
				cmp_ok( $name, 'ge', $last, "In order: $name (" . $query->bridge->as_string( $p ) . ")" );
			} else {
				ok( $name, "$name (" . $query->bridge->as_string( $p ) . ")" );
			}
			$last	= $name;
		} continue { last if ++$count >= 200 };
	}
	
	{
		print "# geo:Point ORDER BY longitude\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	DISTINCT ?name ?lat ?long
			WHERE	{
						[ a geo:Point; foaf:name ?name; geo:lat ?lat; geo:long ?long ]
					}
			ORDER BY ?long
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'CODE', 'stream' );
		my ($count, $last);
		while (my $row = $stream->()) {
			my ($node, $lat, $long)	= @{ $row };
			my $name	= $query->bridge->as_string( $node );
			if (defined($last)) {
				cmp_ok( $query->bridge->as_string( $long ), '>=', $last, "In order: $name (" . $query->bridge->as_string( $long ) . ")" );
			} else {
				ok( $name, "$name (" . $query->bridge->as_string( $long ) . ")" );
			}
			$last	= $query->bridge->as_string( $long );
		} continue { last if ++$count >= 200 };
	}
}
