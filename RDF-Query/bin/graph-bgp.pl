#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(. t lib .. ../t ../lib);
use RDF::Query;
use RDF::Query::Util;

unless (@ARGV) {
	print <<"END";
USAGE: perl $0 query.rq

Graph a BasicGraphPattern's variable connectivity.

END
	exit;
}

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

my $query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;

my ($bgp)	= $query->pattern->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern');
my @triples	= $bgp->triples;

my %vars;
my $g		= new GraphViz (directed => 0, layout => 'circo');
foreach my $i (0 .. $#triples) {
	my $t	= $triples[ $i ];
	$g->add_node( $i, label => "$i" );
	warn "$i\t" . $t->as_sparql() . "\n";
	my @nodes	= $t->nodes;
	foreach my $n (@nodes) {
		if ($n->isa('RDF::Query::Node::Variable')) {
			push( @{ $vars{ $n->name } }, $i );
		} elsif ($n->isa('RDF::Query::Node::Blank')) {
			push( @{ $vars{ '_:' . $n->blank_identifier } }, $i );
		}
	}
}

foreach my $v (keys %vars) {
	my @triples	= @{ $vars{ $v } };
	while (scalar(@triples) > 1) {
		my $t	= shift(@triples);
		foreach my $j (0 .. $#triples) {
			my $u	= $triples[ $j ];
			$g->add_edge( $t => $u, label => "$v" );
		}
	}
}

open( my $fh, '>', "bgp.png" ) or die $!;
print {$fh} $g->as_png;
close($fh);

if (my $opener = $ENV{PNG_VIEWER}) {
	system($opener, 'bgp.png');
}
