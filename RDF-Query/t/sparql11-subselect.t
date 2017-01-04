#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => (5 * scalar(@models));

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		print "# subselect\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT * WHERE {
				?p foaf:schoolHomepage ?school
				{
					SELECT ?p WHERE {
						?p a foaf:Person .
					} LIMIT 1
				}
			}
END
		isa_ok( $query, 'RDF::Query' );
		warn RDF::Query->error unless ($query);
		
		my $iter	= $query->execute( $model );
		my @results	= $iter->get_all;
		is( scalar(@results), 2, 'expected result count' );
		isa_ok( $results[0], 'HASH' );
		
		is_deeply( $results[0]{p}, $results[1]{p}, 'same value bound to ?p' );
		isnt( $results[0]{school}->uri_value, $results[1]{school}->uri_value, 'different values bound to ?school' );
	}
}
