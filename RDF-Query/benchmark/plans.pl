#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);
require "t/models.pl";

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 data.rdf [ \$MBOX_SHA ]

Benchmarks a simple 2-triple BGP execution, trying all possible query plans.

To run this benchmark with your own data, pass \$MBOX_SHA as a valid
foaf:mbox_sha1sum value that is present in data.rdf.

END
	exit;
}

our $MBOX_SHA	= 'f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8';

my @files	= @ARGV;
my @models	= test_models( @files );

use RDF::Query;

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

my ($model)	= first { $_->isa('RDF::Trine::Model') } @models;
my $sparql	= <<"END";
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	SELECT *
	WHERE {
		?person
			foaf:mbox_sha1sum "$MBOX_SHA" ;
			foaf:name ?name ;
		OPTIONAL {
			?person foaf:knows [ foaf:name ?someone ]
		}
	}
END
my $query	= RDF::Query::Benchmark->new( $sparql, undef, undef, 'sparql', optimize => 1 );
my $context	= RDF::Query::ExecutionContext->new(
				bound		=> {},
				model		=> $model,
				query		=> $query,
				optimize	=> 1,
			);
my @plans	= $query->query_plan( $context );

my %plans;
foreach my $i (0 .. $#plans) {
	my $name	= "plan $i";
	warn "$name: " . $plans[ $i ]->sse( {}, ' 'x8 ) . "\n";
	
	$plans{ $name }	= sub {
		local($query->{plan_index})	= $i;
		my $stream	= $query->execute( $model );
		my @res		= $stream->get_all;
	};
}

timethese( 20, \%plans );

package RDF::Query::Benchmark;

use strict;
use warnings;
use base qw(RDF::Query);

sub prune_plans {
	my $self	= shift;
	my @plans	= @_;
	my $index	= $self->{ plan_index };
	return $plans[ $index ];
}
