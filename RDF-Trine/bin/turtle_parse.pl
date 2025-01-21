#!/usr/bin/env perl

=head1 NAME

turtle_parse.pl - Parse Turtle files and output N-Triples

=head1 USAGE

 turtle_parse.pl [-v] FILE [LIMIT]

Parses the input Turtle FILE and prints the resulting RDF as N-Triples.
If LIMIT is specified, exits after LIMIT triples have been output.
If the -v flag is used, the output will end with a summary of the parsing
process as an N-Triples comment.

=cut

use strict;
use warnings;
use RDF::Trine;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
use File::Spec;
use Benchmark qw(:all);
use Error qw(:try);

$|				= 1;
my $verbose		= 0;
if ($ARGV[0] eq '-v') {
	$verbose	= 1;
	shift;
}
my $test_file	= shift;
my $limit		= shift || 0;

# open(my $file, '<:encoding(UTF-8)', $test_file) or die $!;
# open(my $file, '<', $test_file) or die $!;
open(my $file, '<:encoding(UTF-8)', $test_file) or die $!;

my $t0		= [gettimeofday];

my $parser;
my $format;
if ($test_file =~ /[.]trig/) {
	$parser	= RDF::Trine::Parser->new('trig');
	$format	= 'nquads';
} elsif ($test_file =~ /[.]nq/) {
	$parser	= RDF::Trine::Parser->new('nquads');
	$format	= 'nquads';
} else {
	$parser	= RDF::Trine::Parser->new('turtle');
	$format	= 'ntriples';
}

my $base	= File::Spec->rel2abs($test_file);
if ($verbose) {
	$Error::Debug	= 1;
}

my $s	= RDF::Trine::Serializer->new($format);

# Parse test file
my $total = 0;
my $result = timeit(1, sub {
	try {
		$parser->parse_file($base, $file, sub {
			$total++;
			my $st	= shift;
			print $s->statement_as_string($st);
			throw Error::Simple if $limit and $total >= $limit;
		});
	}
	catch RDF::Trine::Error::ParserError::Explainable with {
		my $e	= shift;
		$e->explain( $file );
		exit;
	}
	catch Error::Simple with { };
});

my $elapsed	= tv_interval( $t0, [gettimeofday]);
if ($verbose) {
	print sprintf("# %d triples parsed in %.3fs (%.1f T/s)\n", $total, $elapsed, ($total/$elapsed));
}
