#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

my $tests	= scalar(@models) * 8;
if (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} else {
	plan tests => $tests;
}

use RDF::Query;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	
	{
		print "# FeDeRate BINDINGS (one var)\n";
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?p ?name
			WHERE {
				?p a foaf:Person ; foaf:firstName ?name .
			}
			BINDINGS ?name { ("Gregory") ("Gary") }
END
		my $count	= 0;
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $d = $stream->next) {
			isa_ok( $d, 'HASH' );
			if ($d->{p}->isa('RDF::Trine::Node::Resource')) {
				is( $d->{p}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'expected (URI) node' );
			} elsif ($d->{p}->isa('RDF::Trine::Node::Blank')) {
				my $name	= $d->{name}->literal_value;
				is( $name, 'Gary', 'expected (blank) node' );
			} else {
				fail();
			}
			$count++;
		}
		is( $count, 2, 'expected result count' );
	}
	
	{
		print "# FeDeRate BINDINGS (two var)\n";
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparqlp' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?p
			WHERE {
				?p a foaf:Person ; foaf:name ?name ; foaf:mbox_sha1sum ?email .
			}
			BINDINGS ?name ?email { ("Gregory Todd Williams" "2057969209f1dfdad832de387cf13e6ff8c93b12") }
END
		my $count	= 0;
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $d = $stream->next) {
			$count++;
		}
		is( $count, 0, 'expected result count' );
	}
}
