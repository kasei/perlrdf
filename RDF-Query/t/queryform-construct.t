#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf Flower-2.rdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 23);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			CONSTRUCT { ?person foaf:name ?name }
			WHERE	{ ?person foaf:firstName ?name }
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->next()) {
			my $p	= $stmt->predicate;
			my $s	= $p->as_string;
			ok( $s, "person with firstName: $s" );
			$count++;
		}
		is( $count, 4, 'expected foaf:firstName in construct count' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			CONSTRUCT	{ _:somebody foaf:name ?name; foaf:made ?thing }
			WHERE		{ ?thing dc:creator ?name }
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->next) {
			my $p	= $stmt->predicate;
			my $s	= $p->as_string;
			like( $s, qr#foaf/0.1/(name|made)#, "predicate looks good: $s" );
			$count++;
		}
		is( $count, 8, 'expected dc:creator in construct count' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			CONSTRUCT	{ ?p a foaf:Person ; foaf:aimChatID ?a }
			WHERE		{ ?p a foaf:Person . OPTIONAL { ?p foaf:aimChatID ?a } }
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator', 'stream' );
		my $count	= 0;
		while (my $stmt = $stream->next) {
			my $p	= $stmt->predicate;
			my $s	= $p->as_string;
			like( $s, qr!(foaf/0.1/aimChatID)|(rdf-syntax-ns#type)!, "predicate looks good: $s" );
			$count++;
		}
		is( $count, 5, 'expected optional foaf:aimChatID in construct count' );
	}
}
