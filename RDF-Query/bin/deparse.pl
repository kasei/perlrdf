#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query;
use RDF::Query::Error qw(:try);
use RDF::Query::Util;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $sparql	= 0;
my $algebra	= 0;
my $plan	= 0;
my $explain	= 0;
my $spin	= 0;
while ($ARGV[0] =~ /^-([apPsS])$/) {
	$algebra	= 1 if ($1 eq 'a');
	$plan		= 1 if ($1 eq 'p');
	$explain	= 1 if ($1 eq 'P');
	$sparql		= 1 if ($1 eq 's');
	$spin		= 1 if ($1 eq 'S');
	shift(@ARGV);
}
$sparql	= 1 unless ($algebra || $plan || $sparql || $spin || $explain);

unshift(@ARGV, '-w');
my $query;
try {
	local($Error::Debug)	= 1;
	$query	= &RDF::Query::Util::cli_make_query or die RDF::Query->error;
} catch RDF::Query::Error with {
	my $e	= shift;
	warn $e->stacktrace;
	exit;
};

if ($query) {
	if ($sparql) {
		print "\n# SPARQL:\n";
		print $query->as_sparql . "\n";
	}
	
	if ($algebra) {
		print "\n# Algebra:\n";
		print $query->pattern->sse . "\n";
	}
	
	if ($spin) {
		print "\n# SPIN:\n";
		my $model	= RDF::Trine::Model->temporary_model;
		$query->pattern->as_spin( $model );
		my $spin	= RDF::Trine::Namespace->new('http://spinrdf.org/spin#');
		my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
		my $s	= RDF::Trine::Serializer::Turtle->new( namespaces => { spin => $spin, rdf => $rdf } );
		$s->serialize_model_to_file( \*STDOUT, $model );
	}
	
	if ($explain) {
		print "\n# Plan:\n";
		my $model	= RDF::Trine::Model->temporary_model;
		my ($plan, $ctx)	= $query->prepare( $model );
		print $plan->explain("  ", 0);
	}
	
	if ($plan) {
		print "\n# Plan:\n";
		my $model	= RDF::Trine::Model->temporary_model;
		my ($plan, $ctx)	= $query->prepare( $model );
		print $plan->sse . "\n";
	}
	
	print "\n";
}
