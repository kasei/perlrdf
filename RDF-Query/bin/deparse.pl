#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query;
use RDF::Query::Error qw(:try);
use RDF::Query::Util;

my $sparql	= 0;
my $algebra	= 0;
my $plan	= 0;
while ($ARGV[0] =~ /^-([aps])$/) {
	$algebra	= 1 if ($1 eq 'a');
	$plan		= 1 if ($1 eq 'p');
	$sparql		= 1 if ($1 eq 's');
	shift(@ARGV);
}
$sparql	= 1 unless ($algebra || $plan || $sparql);

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
	
	if ($plan) {
		print "\n# Plan:\n";
		my $model	= RDF::Trine::Model->temporary_model;
		my ($plan, $ctx)	= $query->prepare( $model );
		print $plan->sse . "\n";
	}
	
	print "\n";
}
