#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @models	= test_models();
my $tests	= 1 + (16 * scalar(@models));
plan tests => $tests;

my $file	= URI::file->new_abs( 'data/foaf.xrdf' );
my $rdfa	= URI::file->new_abs( 'data/rdfa-test.xhtml' );

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?page
			FROM
				<$file>
			WHERE
				(?person foaf:name "Gregory Todd Williams")
				(?person foaf:homepage ?page)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		
		my @results	= $query->execute( $model );
		is( scalar(@results), 1, 'result for RDQL query with FROM clause' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{page}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{page}->uri_value, 'http://kasei.us/', 'Got homepage url' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?page
			FROM <$file>
			WHERE { ?person foaf:name "Gregory Todd Williams" ; foaf:homepage ?page }
END
		warn RDF::Query->error unless ($query);
		
		my @results	= $query->execute( $model );
		is( scalar(@results), 1, 'result for SPARQL query with FROM clause' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{page}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{page}->uri_value, 'http://kasei.us/', 'Got homepage url' );
	}
	
	SKIP: {
		unless ($ENV{RDFQUERY_NETWORK_TESTS}) {
			skip "RDFa tests require network access. Set RDFQUERY_NETWORK_TESTS to run these tests.", 6;
		}
		eval "use RDF::RDFa::Parser;";
		skip( "Need RDF::RDFa::Parser to run these tests.", 6 ) if ($@);
		
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql' } );
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT *
			FROM <$rdfa>
			WHERE {
				?s dc:creator ?o
			}
END
		warn RDF::Query->error unless ($query);
		
		my @results	= $query->execute( $model );
		is( scalar(@results), 1, 'result for SPARQL query with FROM clause for RDFa content' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 2, 'got two field' );
		
		my $s	= $results[0]{'s'};
		my $o	= $results[0]{'o'};
		isa_ok( $s, 'RDF::Trine::Node::Resource' );
		isa_ok( $o, 'RDF::Trine::Node::Literal' );
		is( $o->literal_value, 'Mark Birbeck', 'expected value from RDFa data' );
	}
}
