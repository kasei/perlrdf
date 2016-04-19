#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

my $tests	= 2;
plan tests => $tests;

use RDF::Query;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

SKIP: {
	print "# Remote SERVICE invocations\n";
	my $why	= "No network. Set RDFQUERY_NETWORK_TESTS to run these tests.";
	skip $why, 2 unless ($ENV{RDFQUERY_NETWORK_TESTS});
	
	{
		my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } ) or warn RDF::Query->error;
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT DISTINCT *
			WHERE {
				SERVICE <http://myrdf.us/sparql11> {
					?p a foaf:Person ; foaf:name "Gregory Todd Williams" .
					FILTER(ISIRI(?p))
				}
			}
			LIMIT 1
END
		my $model	= RDF::Trine::Model->new();
		my $iter	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $iter->next) {
			$count++;
			is( $row->{p}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'expected URI value from remote SERVICE' );
		}
		is( $count, 1 );
	}
}
