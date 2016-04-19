#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use lib qw(lib ../RDF-Query/lib ../RDF-Trine/lib);

use CGI;
use Log::Log4perl;
use RDF::Query;
use RDF::Query::Util;
use RDF::Endpoint::Server;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.trine.store.dbi	= TRACE, Screen
# #	log4perl.category.rdf.query.util		= DEBUG, Screen
# #	log4perl.category.rdf.query.plan.thresholdunion		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################


if (join(' ', '', @ARGV, '') =~ / --help /) {
	print STDERR <<"END";
USAGE:
       $0 [-p PORT] [-b] [data.rdf]

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
while (@ARGV and $ARGV[0] =~ /^-[pb]$/) {
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
			banner		=> sub { print "You can connect to your server at http://localhost:" . $_[0]->port . "/\n" },
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
