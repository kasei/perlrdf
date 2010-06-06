#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

my $tests	= scalar(@models) * 11;
if (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} else {
	plan tests => $tests;
}

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

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	
	{
		print "# BINDINGS (one var)\n";
		my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
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
		print "# BINDINGS (two var)\n";
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparql11' );
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

	{
		print "# BINDINGS with UNDEF\n";
		my $query	= RDF::Query->new( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT *
			WHERE {
				?p a foaf:Person ; foaf:name ?name ; foaf:schoolHomepage ?school .
			}
			BINDINGS ?name ?school { (UNDEF <http://www.samohi.smmusd.org/>) }
END
		my $count	= 0;
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $d = $stream->next) {
			$count++;
		}
		is( $count, 4, 'expected result count' );
	}
	
	
	SKIP: {
		print "# Remote SERVICE invocations\n";
		my $why	= "No network. Set RDFQUERY_NETWORK_TESTS to run these tests.";
		skip $why, 1 unless ($ENV{RDFQUERY_NETWORK_TESTS});
		
		{
			my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } ) or warn RDF::Query->error;
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT DISTINCT *
				WHERE {
					SERVICE <http://kasei.us/sparql> {
						?p a foaf:Person ; foaf:name "Gregory Todd Williams" .
						FILTER(ISIRI(?p))
					}
				}
				LIMIT 1
END
			my $iter	= $query->execute( $model );
			while (my $row = $iter->next) {
				is( $row->{p}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'expected URI value from remote SERVICE' );
			}
		}
	}
}
