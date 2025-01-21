#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

my %times;
my %elapsed;
while (<>) {
	next unless m#([<>]) (\S+) ([.0-9]+)#;
	my $enter	= ($1 eq '>');
	my $sub		= $2;
	my $time	= $3;
	if ($enter) {
		push( @{ $times{ $sub } }, $time );
	} else {
		my $start	= pop( @{ $times{ $sub } } );
		my $elapsed	= $time - $start;
		$elapsed{ $sub }[0]++;
		$elapsed{ $sub }[1]	+= $elapsed;
	}
}

print "Calls\tS\t\tms/C\t\tSub\n";
foreach my $sub (sort { $elapsed{$b}[1] <=> $elapsed{$a}[1] } (keys %elapsed)) {
	my $calls	= $elapsed{$sub}[0];
	my $cum		= $elapsed{$sub}[1];
	my $cumc	= 1000 * $cum / $calls;
	printf("%d\t%f\t%f\t%s\n", $calls, $cum, $cumc, $sub);
}
