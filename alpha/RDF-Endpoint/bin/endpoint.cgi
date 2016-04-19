#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(/Users/samofool/data/prog/dist/perlrdf/RDF-Endpoint/lib);
use lib qw(lib ../RDF-Query/lib ../RDF-Trine/lib);

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
		);
$s->run( $cgi );
