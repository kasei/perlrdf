#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);
require "t/models.pl";

use RDF::Query::Util;
use RDF::Query::Federate;

use GraphViz;
use List::Util qw(first);
use Time::HiRes qw(tv_interval gettimeofday);

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.federate	= DEBUG, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 query.rq [ service.rdf, ... ]

Graph the QEP produced for a query.

END
	exit;
}

my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;

my @files	= @ARGV;
my @models	= test_models();

my ($model)	= first { $_->isa('RDF::Trine::Model') } @models;

foreach my $file (@files) {
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
warn $plan->sse({}, '');

if (my $opener = $ENV{PNG_VIEWER}) {
	system($opener, 'qep.png');
}
