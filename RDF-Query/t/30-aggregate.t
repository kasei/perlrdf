#!/usr/bin/perl
use strict;
use warnings;
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf about.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => 1 + (4 * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	my $bridge	= RDF::Query->get_bridge( $model );
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?p ?knows
			WHERE {
				?p a foaf:Person ;
					foaf:knows ?knows .
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( ['p'], count => ['COUNT', 'knows'] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my $count	= $row->{count};
			ok( $bridge->is_literal( $count ), 'literal aggregate' );
			is( $bridge->literal_value( $count ), 3, 'foaf:knows count' );
		}
		is( $count, 1, 'one aggreate' );
	}
	
	if (0) {
		my $query	= new RDF::Query ( <<"END" );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?image ?aperture
			WHERE {
				?image a foaf:Image ;
					exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( [], wide => ['MIN', 'aperture'], narrow => ['MAX', 'aperture'] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $wide	= $row->{wide};
			my $narrow	= $row->{narrow};
			ok( $bridge->is_literal( $wide ), 'literal aggregate' );
			ok( $bridge->is_literal( $narrow ), 'literal aggregate' );
			is( $bridge->literal_value( $wide ), 4.5, 'wide (MIN) aperture' );
			is( $bridge->literal_value( $narrow ), 11, 'narrow (MAX) aperture' );
			$count++;
		}
		is( $count, 1, 'one aggreate' );
	}
	
	if (0) {
		my $query	= new RDF::Query ( <<"END" );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT ?place ?date
			WHERE {
				[] a foaf:Image ;
					dcterms:spatial [ foaf:name ?place ] ;
					dc:date ?date
			}
			ORDER BY DESC(?place)
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( ['place'], begin => ['MIN', 'date'], end => ['MAX', 'date'] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		my @expect	= ( ['Providence, RI', ''] );
		while (my $row = $stream->next) {
			use Data::Dumper;
			warn Dumper($row);
# 			my $wide	= $row->{wide};
# 			my $narrow	= $row->{narrow};
# 			ok( $bridge->is_literal( $wide ), 'literal aggregate' );
# 			ok( $bridge->is_literal( $narrow ), 'literal aggregate' );
# 			is( $bridge->literal_value( $wide ), 4.5, 'wide (MIN) aperture' );
# 			is( $bridge->literal_value( $narrow ), 11, 'narrow (MAX) aperture' );
			$count++;
		}
		is( $count, 1, 'one aggreate' );
	}
	
}
