#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use Test::More;
use Test::Exception;
use Scalar::Util qw(refaddr);

use RDF::Query;

if ($ENV{RDFQUERY_TIMETEST}) {
	plan qw(no_plan);
} else {
	plan skip_all => 'Developer tests. Set RDFQUERY_TIMETEST to run these tests.';
	return;
}

use lib qw(. t);
BEGIN { require "models.pl"; }

my $debug	= 1;
my @files	= map { "data/$_" } qw(temporal.rdf);
my @models	= test_models( @files );


my $tests	= 0;
my $find_interval	= <<"END";
	PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
	PREFIX t: <http://www.w3.org/2006/09/time#>
	SELECT ?interval ?b ?e
	WHERE {
		{
			?interval a t:Interval ;
						t:begins ?b ; t:ends ?e .
			FILTER( ?b <= "%s"^^xsd:dateTime && ?e > "%s"^^xsd:dateTime )
		} UNION {
			?interval a t:Interval ;
						t:begins ?b .
			OPTIONAL { ?interval t:ends ?e } .
			FILTER( !BOUND(?e) ) .
			FILTER( ?b <= "%s"^^xsd:dateTime )
		} UNION {
			?interval a t:Interval .
			OPTIONAL { ?interval t:begins ?b } .
			?interval t:ends ?e .
			FILTER( !BOUND(?b) ) .
			FILTER( ?e > "%s"^^xsd:dateTime )
		} UNION {
			?interval a t:Interval .
			OPTIONAL { ?interval t:begins ?b } .
			OPTIONAL { ?interval t:ends ?e } .
			FILTER( !BOUND(?b) && !BOUND(?e) ) .
		}
	}
END

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	{
		# find intervals that contain a specific date
		my $dt		= '1999-06-01';
		my $sparql	= sprintf( $find_interval, ($dt) x 4 );
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $data = $stream->next) {
			my $interval	= $data->[0];
			ok( $interval->isa('RDF::Trine::Node'), 'time-intervals' );
			like( $interval->uri_value, qr/#yearTo2000/, 'time-intervals: 1999' );
			$count++;
		}
		is( $count, 1, '1999: correct count of matching intervals' );
	}
	
	{
		# find intervals that contain a specific date
		my $dt		= '2000-06-01';
		my $sparql	= sprintf( $find_interval, ($dt) x 4 );
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $data = $stream->next) {
			my $interval	= $data->[0];
			ok( $interval->isa('RDF::Trine::Node'), 'time-intervals' );
			like( $interval->uri_value, qr/#year2000/, 'time-intervals: 2000' );
			$count++;
		}
		is( $count, 1, '2000: correct count of matching intervals' );
	}
	
	{
		# find intervals that contain a specific date
		my $dt		= '2002-06-01';
		my $sparql	= sprintf( $find_interval, ($dt) x 4 );
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $data = $stream->next) {
			my $interval	= $data->[0];
			$count++;
		}
		is( $count, 0, '2002: correct count of matching intervals' );
	}
	
	{
		# find intervals that contain a specific date
		my $dt		= '2005-06-01';
		my $sparql	= sprintf( $find_interval, ($dt) x 4 );
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $data = $stream->next) {
			my $interval	= $data->[0];
			ok( $interval->isa('RDF::Trine::Node'), 'time-intervals' );
			like( $interval->uri_value, qr/#yearFrom2003/, 'time-intervals: 2005' );
			$count++;
		}
		is( $count, 1, '2005: correct count of matching intervals' );
	}
}

