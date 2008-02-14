#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Scalar::Util qw(blessed refaddr);

if ($ENV{RDFQUERY_TIMETEST}) {
	plan qw(no_plan);
} else {
	plan skip_all => 'Developer tests. Set RDFQUERY_TIMETEST to run these tests.';
	return;
}

use_ok('RDF::Query::Temporal');

use lib qw(. t);
BEGIN { require "models.pl"; }

my $debug	= 1;
my @files	= map { "data/$_" } (); #qw(temporal.rdf);
my ($model)	= grep { blessed($_) and $_->isa('RDF::Redland::Model') } test_models( @files );

unless ($model) {
	exit;
}

my $tests	= 0;

print "\n#################################\n";
print "### Using model: $model\n";
SKIP: {
	### IMPORT TEMPORAL DATA ###############################################
	my $head	= <<'END';
	@prefix : <http://kasei.us/foaf/about.xrdf#> .
	@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
	@prefix foaf: <http://xmlns.com/foaf/0.1/> .
	@prefix time: <http://www.w3.org/2006/09/time#> .
	@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
END
	my %data	= (
		''		=> <<'END',
				<http://kasei.us/e/time/all> rdf:type time:Interval .
				<http://kasei.us/e/time/all> rdfs:label "Perpetuity" .
				
				<http://kasei.us/e/time/D09CBCC0-1363-480A-9F7C-62ABB52F073F> rdf:type time:Interval .
				<http://kasei.us/e/time/D09CBCC0-1363-480A-9F7C-62ABB52F073F> time:begins "2006-09-01" .
				<http://kasei.us/e/time/D09CBCC0-1363-480A-9F7C-62ABB52F073F> time:ends "2007-08-31" .
				
				<http://kasei.us/e/time/5F9DFA61-5CFB-4525-9D19-7B29D2C2FD85> rdf:type time:Interval .
				<http://kasei.us/e/time/5F9DFA61-5CFB-4525-9D19-7B29D2C2FD85> time:begins "1996-09-18" .
				<http://kasei.us/e/time/5F9DFA61-5CFB-4525-9D19-7B29D2C2FD85> time:ends "2001-01-22" .
END
		'http://kasei.us/e/time/all'		=> <<'END',
				:greg rdf:type foaf:Person .
				:greg foaf:mbox <mailto:gwilliams@cpan.org> .
END
		'http://kasei.us/e/time/D09CBCC0-1363-480A-9F7C-62ABB52F073F'		=> <<'END',
				:greg rdf:type foaf:Person .
				:greg foaf:mbox <mailto:gtw@cs.umd.edu> .
END
		'http://kasei.us/e/time/5F9DFA61-5CFB-4525-9D19-7B29D2C2FD85'		=> <<'END',
				:greg rdf:type foaf:Person .
				:greg foaf:mbox <mailto:greg@cnation.com> .
END
	);
	
	my $load_temporal_data	= sub {
		my $query	= shift;
		my $bridge	= RDF::Query->get_bridge( $model );
		my $model	= $bridge->model;
		my $base	= RDF::Redland::URI->new('http://kasei.us/e/ns/');
		foreach my $graph (keys %data) {
			my $rdf		= $data{ $graph };
			my $context	= RDF::Redland::URI->new( $graph );
			my $string	= join("\n", $head, $rdf);
			my $parser	= RDF::Redland::Parser->new("turtle");
			if ($graph) {
				my $stream	= $parser->parse_string_as_stream($string, $base);
				$model->add_statements( $stream, $context );
			} else {
				$parser->parse_string_into_model($string, $base, $model);
			}
		}
	};
	########################################################################
	
	
	
	{
		warn "####################\n";
		my $query	= new RDF::Query ( <<'END', undef, undef, 'sparql' );
			# select all the email addresses ever held by the person
			# who held a given email address on 2006-01-01
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX t: <http://www.w3.org/2006/09/time#>
			SELECT ?mbox WHERE {
				GRAPH ?time { ?p foaf:mbox <mailto:gtw@cs.umd.edu> } .
				?time t:inside "2006-01-01" .
				?p foaf:mbox ?mbox .
			}
END
		$load_temporal_data->( $query );
		my @results	= $query->execute( $model );
		is( scalar(@results), 0, 'expected no results' );
	}
	
	{
		# find intervals that contain a specific date
		my $dt		= '2003-01-01';
		my $sparql	= sprintf( <<"END", ($dt) x 4 );
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
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		$load_temporal_data->( $query );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $data = $stream->next) {
			my $interval	= $data->{interval};
			ok( $query->bridge->is_node( $interval ), 'time-intervals' );
			like( $query->bridge->uri_value( $interval ), qr'http://kasei.us/e/time/all', 'time-intervals: uri' );
			$count++;
		}
		is( $count, 1, 'expected count of matching intervals' );
	}
	
	{
		my $query	= new RDF::Query::Temporal ( <<'END', undef, undef, 'sparqlp' );
			# select all the email addresses ever held by the person
			# who held a given email address on 2007-01-01
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX t: <http://www.w3.org/2006/09/time#>
			SELECT ?mbox WHERE {
				TIME [ t:inside "2007-01-01" ] { ?p foaf:mbox <mailto:gtw@cs.umd.edu> } .
				?p foaf:mbox ?mbox .
			}
END
		$load_temporal_data->( $query );
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got TIME result: time-inside-2007-01-01' );
		foreach my $r (@results) {
			no warnings 'uninitialized';
			my $e	= $query->bridge->as_string( $r->[0] );
			like( $e, qr/mailto:/, "email: $e" );
		}
	}

	{
		my $query	= new RDF::Query::Temporal ( <<'END', undef, undef, 'sparqlp' );
			# select all people who had email addresses on 2002-01-01
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX t: <http://www.w3.org/2006/09/time#>
			SELECT ?p ?e WHERE {
				TIME [ t:inside "2002-01-01" ] { ?p foaf:mbox ?e } .
			}
END
		$load_temporal_data->( $query );
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got TIME result: time-all-email' );
		foreach my $r (@results) {
			no warnings 'uninitialized';
			my $p	= $query->bridge->as_string( $r->[0] );
			my $e	= $query->bridge->as_string( $r->[1] );
			like( $p, qr/#greg/, "person: $p" );
			like( $e, qr/gwilliams[@]cpan.org/, "email: $e" );
		}
	}

	{
		my $query	= new RDF::Query::Temporal ( <<'END', undef, undef, 'sparqlp' );
			# select all the email addresses ever held by the person
			# who held a given email address on 2006-01-01
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX t: <http://www.w3.org/2006/09/time#>
			SELECT ?mbox WHERE {
				TIME [ t:inside "2006-01-01" ] { ?p foaf:mbox <mailto:gtw@cs.umd.edu> } .
				?p foaf:mbox ?mbox .
			}
END
		$load_temporal_data->( $query );
		my @results	= $query->execute( $model );
		is( scalar(@results), 0, 'expected no results' );
	}
}

