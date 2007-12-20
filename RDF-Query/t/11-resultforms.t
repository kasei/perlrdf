#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 26);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	{
		my %seen;
		{
			print "# foaf:Person ORDER BY name with LIMIT\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				SELECT	DISTINCT ?p ?name
				WHERE	{
							?p a foaf:Person; foaf:name ?name .
							FILTER(lang(?name) = "")
						}
				ORDER BY ?name
				LIMIT 2
END
			my $stream	= $query->execute( $model );
			my $bridge	= $query->bridge;
			isa_ok( $stream, 'RDF::Trice::Iterator' );
			my ($count, $last);
			while (my $row = $stream->()) {
				my ($p, $node)	= @{ $row }{qw(p name)};
				my $name	= $bridge->literal_value( $node );
				$seen{ $name }++;
				if (defined($last)) {
					cmp_ok( $name, 'ge', $last, "In order: $name (" . $bridge->as_string( $p ) . ")" );
				} else {
					ok( $name, "First: $name (" . $bridge->as_string( $p ) . ")" );
				}
				$last	= $name;
			} continue { ++$count };
			is( $count, 2, 'good LIMIT' );
		}
		
		{
			print "# foaf:Person ORDER BY name with LIMIT and OFFSET\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				SELECT	DISTINCT ?p ?name
				WHERE	{
							?p a foaf:Person; foaf:name ?name .
							FILTER(lang(?name) = "")
						}
				ORDER BY ?name
				LIMIT 2
				OFFSET 2
END
			my $stream	= $query->execute( $model );
			my $bridge	= $query->bridge;
			isa_ok( $stream, 'RDF::Trice::Iterator' );
			my ($count, $last);
			while (my $row = $stream->next) {
				my ($p, $node)	= @{ $row }{qw(p name)};
				my $name	= $bridge->literal_value( $node );
				is( exists($seen{ $name }), '', "not seen before with offset: $name" );
				if (defined($last)) {
					cmp_ok( $name, 'ge', $last, "In order: $name (" . $bridge->as_string( $p ) . ")" );
				} else {
					ok( $name, "First: $name (" . $bridge->as_string( $p ) . ")" );
				}
				$last	= $name;
			} continue { ++$count };
			is( $count, 1, 'good LIMIT' );
		}
	}
	
	{
		print "# foaf:Person with LIMIT\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?p ?name
			WHERE	{
						?p a foaf:Person; foaf:name ?name
					}
			LIMIT 2
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trice::Iterator' );
		my ($count);
		while (my $row = $stream->next) {
			my ($p, $node)	= @{ $row }{qw(p name)};
			my $name	= $bridge->literal_value( $node );
			ok( $name, "First: $name (" . $bridge->as_string( $p ) . ")" );
		} continue { ++$count };
		is( $count, 2, 'good LIMIT' );
	}
	
	{
		print "# foaf:Person with ORDER BY and OFFSET\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	DISTINCT ?p ?name
			WHERE	{
						?p a foaf:Person; foaf:nick ?nick; foaf:name ?name
					}
			ORDER BY ?name
			OFFSET 1
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trice::Iterator' );
		my ($count);
		while (my $row = $stream->next) {
			my ($p, $node)	= @{ $row }{qw(p name)};
			my $name	= $bridge->literal_value( $node );
			ok( $name, "Got person with nick: $name (" . $bridge->as_string( $p ) . ")" );
		} continue { ++$count };
		is( $count, 1, "Good DISTINCT with OFFSET" );
	}
	
	{
		print "# foaf:Image with OFFSET [2]\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	DISTINCT ?name ?camera
			WHERE	{
						?img a foaf:Image .
						?img dc:creator ?name .
						?img exif:model ?camera
					}
			OFFSET 1
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trice::Iterator' );
		my ($count);
		while (my $row = $stream->next) {
			my ($n, $c)	= @{ $row }{qw(name camera)};
			my $name	= $bridge->literal_value( $n );
			ok( $name, "Got image creator: $name" );
		} continue { ++$count };
		is( $count, 1, "Good DISTINCT with LIMIT" );
	}
	
	{
		print "# foaf:Image with ORDER BY ASC(expression) [1]\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX	exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	DISTINCT ?img ?long
			WHERE	{
						?img a foaf:Image .
						?img dcterms:spatial ?point .
						?point geo:long ?long .
					}
			ORDER BY ASC(?long * -1)
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trice::Iterator' );
		my $count	= 0;
		
		my $min;
		while (my $row = $stream->next) {
			my ($i, $l)	= @{ $row }{qw(img long)};
			my $image	= $bridge->uri_value($i);
			my $long	= $bridge->literal_value($l);
			if (defined($min)) {
				cmp_ok( $long, '<=', $min, "decreasing longitude $long on $image" );
				if ($long <= $min) {
					$min	= $long;
				}
			} else {
				is( $image, 'http://kasei.us/pictures/2004/20040909-Ireland/images/DSC_5705.jpg' );
				$min	= $long;
			}
		} continue { last if ++$count == 2 };
		is( $count, 2, "Good ORDER BY ASC(expression) [1]" );
	}
	
	{
		print "# foaf:Image with ORDER BY DESC(expression) [2]\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX	exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	DISTINCT ?img ?long
			WHERE	{
						?img a foaf:Image .
						?img dcterms:spatial ?point .
						?point geo:long ?long .
					}
			ORDER BY DESC(?long * -1)
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trice::Iterator' );
		my $count	= 0;
		
		my $max;
		while (my $row = $stream->next) {
			my ($i, $l)	= @{ $row }{qw(img long)};
			my $image	= $bridge->uri_value($i);
			my $long	= $bridge->literal_value($l);
			if (defined($max)) {
				cmp_ok( $long, '>=', $max, "increasing longitude $long on $image" );
				if ($long >= $max) {
					$max	= $long;
				}
			} else {
				cmp_ok( $long, '==', -71.3924 );
				$max	= $long;
			}
		} continue { last if ++$count == 2 };
		is( $count, 2, "Good ORDER BY DESC(expression) [2]" );
	}
}
