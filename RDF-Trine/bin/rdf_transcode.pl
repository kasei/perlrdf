#!/usr/bin/env perl

use strict;
use warnings;
use threads qw(yield);
use threads::shared;
use Storable qw(freeze thaw);
use RDF::Trine;
use Getopt::Long;
use Time::HiRes qw(usleep);

my %namespaces;
my $in	= 'ntriples';
my $out	= 'rdfxml';
my $result	= GetOptions ("in=s" => \$in, "out=s" => \$out, "define=s" => \%namespaces, "D=s" => \%namespaces);

unless (@ARGV) {
	print <<"END";
Usage: $0 -i in_format -o out_format rdf_data.filename

END
	exit;
}

my $file	= shift or die "An RDF filename must be given";
open( my $fh, '<:encoding(UTF-8)', $file ) or die $!;

my $done :shared;
my $st :shared;

$done			= 0;
my $parser		= RDF::Trine::Parser->new($in);
my $serializer	= RDF::Trine::Serializer->new($out, namespaces => \%namespaces);
my $handler		= sub {
	my $s		= shift;
	lock($st);
	$st	= freeze($s);
	cond_broadcast($st);
};

my $thr = async {
	$parser->parse_file( 'http://base/', $fh, $handler );
# 	warn "done parsing";
	lock($st);
	$st	= undef;
	$done	= 1;
# 	warn "broadcasting finish state";
	cond_broadcast($st);
};

my $iter	= RDF::Trine::Iterator::Graph->new( sub {
	while (1) {
		lock($st);
		if ($done) {
# 			warn "got finish state";
			return;
		}
		cond_wait($st);
		if (defined($st)) {
			my $s	= thaw($st);
			$st		= undef;
			return $s;
		}
		usleep(10);
	}
} );

binmode(\*STDOUT, ':encoding(UTF-8)');
# warn "serializing to STDOUT";
$serializer->serialize_iterator_to_file( \*STDOUT, $iter );
# warn "done";
$thr->join();
