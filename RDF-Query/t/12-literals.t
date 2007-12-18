#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw(no_plan);

use_ok( 'RDF::Query' );
use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";


	{
		print "# language typed literal\n";
		my $query	= new RDF::Query ( <<'END', undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?homepage
			WHERE	{
						?person foaf:name "Gary Peck"@en ; foaf:homepage ?homepage .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Iterator' );
		my $current	= $stream->current;
		isa_ok( $current, 'HASH' );
		my ($p, $h)	= @{ $current }{qw(person homepage)};
		ok( $query->bridge->is_resource( $h ), 'Got a resource for homepage' );
		is( $query->bridge->uri_value( $h ), 'http://www.realify.com/~gary/', 'Got homepage' );
	}
	
	SKIP: {
		print "# datatyped literal\n";
		my $query	= new RDF::Query ( <<'END', undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	?image
			WHERE	{
						?image dc:date "2005-04-07T18:27:56-04:00"^^<http://www.w3.org/2001/XMLSchema#dateTime>
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Iterator' );
		my $current	= $stream->current;
		isa_ok( $current, 'HASH' );
		my ($h)	= @{ $current }{image};
		ok( $query->bridge->is_resource( $h ), 'Got a resource for image' );
		is( $query->bridge->uri_value( $h ), 'http://kasei.us/pictures/2005/20050422-WCCS_Dinner/images/DSC_8057.jpg', 'Got image by typed date' );
	}
}
