#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);
require "t/models.pl";

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 query.rq data.rdf

Graph the QEP produced for a query.

END
	exit;
}

my $qfile	= shift;
my $sparql	= do { open(my $fh, '<', $qfile) or die $!; local($/) = undef; <$fh> };
my @files	= @ARGV;
my @models	= test_models( @files );

use RDF::Query::Federate;
use RDF::Query::CostModel::Naive;

use GraphViz;
use List::Util qw(first);
use Time::HiRes qw(tv_interval gettimeofday);
use Benchmark;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.federate	= DEBUG, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my ($model)	= first { $_->isa('RDF::Trine::Model') } @models;
my $query	= RDF::Query::Federate->new( $sparql, {  optimize => 1 } );
warn RDF::Query->error unless ($query);

foreach my $file (qw(data/service.ttl data/service-kasei.ttl)) {
	my $uri	= URI::file->new_abs( $file );
	my $sd	= RDF::Query::ServiceDescription->new_from_uri( $uri );
	$query->add_service( $sd );
}

my ($plan, $ctx)	= $query->prepare( $model );
my $g		= new GraphViz;
$plan->graph( $g );
open( my $fh, '>', "qep.png" ) or die $!;
print {$fh} $g->as_png;
close($fh);

if (my $opener = $ENV{PNG_VIEWER}) {
	system($opener, 'qep.png');
}
