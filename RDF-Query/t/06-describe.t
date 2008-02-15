#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 72);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			DESCRIBE ?person
			WHERE	{ ?person foaf:name "Gregory Todd Williams" }
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		ok( $stream->is_graph, "Stream is graph result" );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->()) {
			my $p	= $bridge->predicate( $stmt );
			my $s	= $bridge->as_string( $p );
			ok( $s, $s );
			++$count;
		}
		is( $count, 33 );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			DESCRIBE ?person
			WHERE {
				?image a foaf:Image ; foaf:maker ?person .
			}
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		ok( $stream->is_graph, "Stream is graph result" );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->()) {
			my $p	= $bridge->predicate( $stmt );
			my $s	= $bridge->as_string( $p );
			ok( $s, $s );
			++$count;
		}
		is( $count, 33 );
	}
}
