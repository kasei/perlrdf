#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(lib);
use Test::Harness;
use Test::Harness::Util qw( all_in blibdirs shuffle );
use Data::Dumper;
use Getopt::Simple;

my($options) = {
	v => {
		type	=> '+',
		env		=> '$RDFQUERY_VERBOSE',
		verbose	=> 'Be verbose',
	},
	help => {
		type    => '',
		env     => '-',
		default => '',
		order   => 1,
	},
	model => {
		type    => '=s',    # As per Getopt::Long.
		env     => '$RDFQUERY_MODEL',
		verbose => 'Specify the model name',
		order   => 3,       # Help text sort order.
	},
	tests => {
		type	=> '=s',
		env		=> '-',
		default	=> '',
		verbose => 'Regular expression filter for test files',
	},
	parser => {
		type	=> '=s',
		env		=> '$RDFQUERY_PARSER',
		default	=> 'sparql',
		verbose	=> 'Short name of the default query parser to use',
	},
};

my($option) = Getopt::Simple -> new();

if (!$option->getOptions($options, "Usage: $0 [options]")) {
	exit(-1);
}

if ($$option{'switch'}{'help'}) {
	$option->helpOptions();
	exit(0);       # Failure.
}

if (my $p = $$option{'switch'}{'parser'}) {
	no warnings 'once';
	$RDF::Query::DEFAULT_PARSER	= $p;
}

my $VERBOSE	= $$option{'switch'}{'v'};

my @models	= qw(redland rdfcore rdfbase);
my %models	= map { $_ => 1 } @models;
if (my $m = $$option{'switch'}{'model'}) {
	if (not exists($models{$m})) {
		print "Unknown model $m. Available models are:"
			. join("\n\t- ", '', @models) . "\n\n";
		exit(-1);
	}
	
	my $mn	= uc($m);
	foreach my $n (map uc, @models) {
		if ($n ne $mn) {
			warn "Setting RDFQUERY_NO_$n ...\n" if ($VERBOSE);
			$ENV{"RDFQUERY_NO_$n"}	= 1;
		}
	}
	
	require "t/models.pl";
}


if ($VERBOSE) {
	$Test::Harness::Verbose	= 1;
}

my @files	= grep { /$$option{switch}{tests}/ } all_in( { recurse => 1, start => 't/' } );
runtests(@files);

