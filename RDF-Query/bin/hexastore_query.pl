#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use URI::file;

use lib qw(. t lib .. ../t ../lib);

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 data.hxs query.rq

END
	exit;
}

use RDF::Query;
use RDF::Trine::Store::Hexastore;

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

my $file	= shift;
my $sparql	= do { local($/) = undef; <> };
my $store	= RDF::Trine::Store::Hexastore->load( $file );
my $model	= RDF::Trine::Model->new( $store );

#DB::enable_profile();
my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql', optimize => 1 );
my ($p,$c)	= $query->prepare( $model );
my $stream	= $query->execute_plan( $p, $c );
while (my $r = $stream->next) {
	print "$r\n";
}
#DB::disable_profile();
