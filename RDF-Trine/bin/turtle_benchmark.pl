#!/usr/bin/perl

=head1 NAME

turtle_benchmark.pl - Benchmark tool for Turtle parser

=head1 USAGE

 turtle_benchmark.pl FILE [LIMIT]

Parses the input turtle FILE and prints the overall parsing speed.
If LIMIT is specified, stops after LIMIT triples have been parsed.

=cut

use strict;
use warnings;
use RDF::Trine;
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Parser::Turtle;

$|				= 1;
my $filename	= shift;
my $limit		= shift || 0;
open(my $fh, '<:encoding(UTF-8)', $filename) or die $!;
my $count	= 0;
my $t0		= [gettimeofday];
my $p		= RDF::Trine::Parser::Turtle->new();
eval {
	$p->parse_file(undef, $fh, sub {
		$count++;
		print STDERR "\r$count" unless ($count % 7);
		die if ($limit and $count >= $limit);
	});
};
my $elapsed	= tv_interval( $t0, [gettimeofday]);
printf("\nParsed %d triples in %.1fs (%.1f T/s)\n", $count, $elapsed, ($count/$elapsed));
