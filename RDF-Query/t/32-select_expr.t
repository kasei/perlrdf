#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my $tests	= 11;
my @models	= test_models( qw(data/greenwich.rdf) );
plan tests => 1 + ($tests * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	SKIP: {
		{
			print "# DATATYPE() comparison\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
				SELECT	?lat (?long + 1.0 AS ?long_off)
				WHERE	{ ?point a geo:Point ; geo:lat ?lat ; geo:long ?long . }
END
			my $count	= 0;
			my $stream	= $query->execute( $model );
			my $bridge	= $query->bridge;
			while (my $row = $stream->next) {
				my ($lat, $long)	= @{ $row }{qw(lat long_off)};
				is( $bridge->literal_value( $lat ), '51.477222', 'existing latitude' );
				cmp_ok( $bridge->literal_value( $long ), '==', 1, 'modified longitude' );
			} continue { ++$count };
			is( $count, 1, 'expecting one statement in model' );
			exit;
		}
	}
}
