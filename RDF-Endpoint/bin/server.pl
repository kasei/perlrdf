#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use lib qw(lib ../RDF-Query/lib ../RDF-Store-DBI/lib ../RDF-SPARQLResults/lib);

use RDF::Query::Util;
use RDF::Endpoint::Server;

unless (@ARGV) {
	print STDERR <<"END";
USAGE:
       $0 [-p PORT] [-b] data.rdf

Starts a SPARQL endpoint on the specified port (defaults to 9680). After
starting, the endpoint is accessible over HTTP at, e.g.

http://localhost:9680/

If the -b flag is specified, attempts to announce the SPARQL endpoint using
Bonjour (zeroconf) using the L<Net::Rendezvous::Publish|Net::Rendezvous::Publish>
module.

END
	exit;
}

$0		= 'sparql-endpoint';

$ENV{TMPDIR}	= '/tmp';
my $cgi	= CGI->new;
my $port		= 9680;
my $announce	= 0;
while (@ARGV and $ARGV[0] =~ /^-[pb]/) {
	if ($ARGV[0] eq '-p') {
		shift(@ARGV);
		$port	= shift(@ARGV);
	} elsif ($ARGV[0] eq '-b') {
		shift(@ARGV);
		$announce	= 1;
	}
}

my $model = &RDF::Query::Util::cli_make_model;
my $s	= RDF::Endpoint::Server->new_with_model( $model,
			Port		=> $port,
			Prefix		=> '',
			CGI			=> $cgi,
		);

if ($announce) {
	require threads;
	require Net::Rendezvous::Publish;
	threads->create(sub{my $publisher = Net::Rendezvous::Publish->new
	or die "couldn't make a Responder object";
	my $service = $publisher->publish(
		name => "SPARQL Endpoint",
		type => '_sparql._tcp',
		path => '/',
		port => $port,
	);
	while (1) { $publisher->step( 0.01 ) }
	});
}

my $pid	= $s->run();
print "Endpoint started as [$pid]\n";
