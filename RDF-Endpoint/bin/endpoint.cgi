#!/usr/bin/perl

use strict;
use warnings;

use lib qw(/Users/samofool/data/prog/dist/perlrdf/RDF-Endpoint/lib);

use CGI;
use RDF::Endpoint::CGI;

$ENV{TMPDIR}	= '/tmp';
my $cgi	= CGI->new();
my $s	= RDF::Endpoint::CGI->new(
			Port			=> 8082,
			DBServer		=> $ENV{DBServer} || 'DBI:mysql:database=test',
			DBUser			=> $ENV{DBUser} || 'test',
			DBPass			=> $ENV{DBPass} || 'test',
			Model			=> 'endpoint',
			Prefix			=> '/~samofool/endpoint/index.cgi',
			IncludePath		=> '/Users/samofool/data/prog/dist/perlrdf/RDF-Endpoint/include',
			CGI				=> $cgi,
			WhiteListModel	=> 'whitelist',
		);
$s->run( $cgi );
