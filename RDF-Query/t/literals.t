#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

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
						?person foaf:name "Gary P"@en ; foaf:homepage ?homepage .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $current	= $stream->current;
		isa_ok( $current, 'HASH' );
		my ($p, $h)	= @{ $current }{qw(person homepage)};
		ok( $h->isa('RDF::Trine::Node::Resource'), 'Got a resource for homepage' );
		is( $h->uri_value, 'http://www.realify.com/~gary/', 'Got homepage' );
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
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $current	= $stream->current;
		isa_ok( $current, 'HASH' );
		my ($h)	= @{ $current }{image};
		ok( $h->isa('RDF::Trine::Node::Resource'), 'Got a resource for image' );
		is( $h->uri_value, 'http://kasei.us/pictures/2005/20050422-WCCS_Dinner/images/DSC_8057.jpg', 'Got image by typed date' );
	}
}

done_testing;
