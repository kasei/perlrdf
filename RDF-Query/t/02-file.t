#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More tests => 20;
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @models	= test_models();

my $file	= URI::file->new_abs( 'data/foaf.xrdf' );

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
		is( scalar(@results), 1, 'Got one result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $query->bridge->isa_resource( $results[0]{page} ), 'Resource' );
		is( $query->bridge->uri_value( $results[0]{page} ), 'http://kasei.us/', 'Got homepage url' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?page
			FROM <$file>
			WHERE { ?person foaf:name "Gregory Todd Williams" ; foaf:homepage ?page }
END
		warn RDF::Query->error unless ($query);
		
		my @results	= $query->execute( $model );
		is( scalar(@results), 1, 'Got one result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $query->bridge->isa_resource( $results[0]{page} ), 'Resource' );
		is( $query->bridge->uri_value( $results[0]{page} ), 'http://kasei.us/', 'Got homepage url' );
	}
}
