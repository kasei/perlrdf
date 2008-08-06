#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);
require "t/models.pl";

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 data.rdf [ \$MBOX_SHA ]

Benchmarks a simple 2-triple BGP execution. Two different orderings of the
BGP are given, and for each, the query is run with and without a cost model
object. The cost model will allow the BGP to be re-ordered prior to execution,
placing the more selective triple pattern (the one with fewest variables)
first, thus minimizing intermediate query results.

To run this benchmark with your own data, pass \$MBOX_SHA as a valid
foaf:mbox_sha1sum value that is present in data.rdf.

END
	exit;
}

our $MBOX_SHA	= 'f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8';

my @files	= @ARGV;
my @models	= test_models( @files );

use RDF::Query;
use RDF::Query::CostModel::Naive;

use List::Util qw(first);
use Time::HiRes qw(tv_interval gettimeofday);
use Benchmark;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.algebra          = DEBUG, Screen
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my ($model)	= first { $_->isa('RDF::Core::Model') } @models;
my $costmodel	= RDF::Query::CostModel::Naive->new();

timethese( 100, {
	'no cost model, pre-optimized BGP' => sub {
		my $sparql	= <<"END";
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT *
WHERE {
	?person
		foaf:mbox_sha1sum "$MBOX_SHA" ;
		foaf:name ?name ;
}
END
		query( $sparql );
	},
	'no cost model, unoptimized BGP' => sub {
		my $sparql	= <<"END";
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT *
WHERE {
	?person
		foaf:name ?name ;
		foaf:mbox_sha1sum "$MBOX_SHA" ;
}
END
		query( $sparql );
	},
	'with cost model, pre-optimized BGP' => sub {
		my $sparql	= <<"END";
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT *
WHERE {
	?person
		foaf:mbox_sha1sum "$MBOX_SHA" ;
		foaf:name ?name ;
}
END
		query( $sparql, costmodel => $costmodel );
	},
	'with cost model, unoptimized BGP' => sub {
		my $sparql	= <<"END";
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT *
WHERE {
	?person
		foaf:name ?name ;
		foaf:mbox_sha1sum "$MBOX_SHA" ;
}
END
		query( $sparql, costmodel => $costmodel );
	},
} );

sub query {
	my $sparql	= shift;
	my %args	= @_;
	my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql', %args );
	my $stream	= $query->execute( $model );
	my @res		= $stream->get_all;
}
