#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 6);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; foaf:name ?name ]
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Iterator', 'stream' );
		my $count;
		while (not $stream->finished) {
			my ($node)	= $stream->binding_value( 0 );
			my $name	= $query->bridge->as_string( $node );
			ok( $name, $name );
		} continue {
			last if ++$count >= 100;
			$stream->next_result;
		};
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; foaf:name ?name ]
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Iterator', 'stream' );
		my $count;
		while (my $row = $stream->()) {
			my ($node)	= $row->{name};
			my $name	= $query->bridge->as_string( $node );
			ok( $name, $name );
		} continue { last if ++$count >= 100 };
	}
}
