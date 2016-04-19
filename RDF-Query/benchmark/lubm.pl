#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use URI::file;

use lib qw(. t lib .. ../t ../lib);

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 lubm.hxs

END
	exit;
}

my @files	= @ARGV;

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

my $store	= RDF::Trine::Store::Hexastore->load( @ARGV );
my $model	= RDF::Trine::Model->new( $store );

warn "Finished loading data...\n";

# my $sparql	= <<"END";
# PREFIX : <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
# SELECT DISTINCT * WHERE {
# 	?z a :Department .
# 	?z :subOrganizationOf ?y .
# 	?y a :University .
# 	?x :undergraduateDegreeFrom ?y .
# 	?x a :GraduateStudent .
# 	?x :memberOf ?z .
# }
# END

my $sparql	= <<"END";
PREFIX : <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
SELECT DISTINCT * WHERE {
	<http://www.Department0.University0.edu/AssociateProfessor0> :teacherOf ?y .
	?y a :Course .
	?x :takesCourse ?y .
	?x a :Student .
}
END



timethese( 1, {
	'frequency optimized' => sub {
		query( $sparql, 1 );
	},
	'unoptimized' => sub {
		query( $sparql, 0 );
	},
} );

sub query {
	my $sparql	= shift;
	my $opt		= shift;
	my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql', optimize => $opt );
	my ($p,$c)	= $query->prepare( $model );
	warn $p->sse;
	my $stream	= $query->execute_plan( $p, $c );
	my @res		= $stream->get_all;
}
