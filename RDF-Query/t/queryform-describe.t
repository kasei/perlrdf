#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );

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
		ok( $stream->is_graph, "Stream is graph result" );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->next) {
			my $p	= $stmt->predicate;
			my $s	= $p->as_string;
			ok( $s, $s );
			++$count;
		}
#		is( $count, 54, 'describe person expected graph size' );
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
		ok( $stream->is_graph, "Stream is graph result" );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->next) {
			my $p	= $stmt->predicate;
			my $s	= $p->as_string;
			ok( $s, $s );
			++$count;
		}
#		is( $count, 54, 'describe person expected graph size' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			DESCRIBE <http://kasei.us/about/foaf.xrdf>
END
		my $stream	= $query->execute( $model );
		ok( $stream->is_graph, "Stream is graph result" );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'describe resource returns graph iterator' );
		my $count	= 0;
		while (my $stmt = $stream->next) {
			my $p	= $stmt->predicate;
			like( $p->uri_value, qr<^(http://xmlns.com/foaf/0.1/maker|http://www.w3.org/1999/02/22-rdf-syntax-ns#type|http://xmlns.com/wot/0.1/assurance|http://purl.org/dc/elements/1.1/(title|description|date))$>, 'expected predicate' );
			++$count;
		}
		is( $count, 6, 'describe resource expected graph size' );
	}
}

done_testing;
