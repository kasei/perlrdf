#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Plack::Request;
use Config::JFDI;
use Carp qw(confess);
use RDF::Endpoint;

my $config	= Config::JFDI->open( name => "RDF::Endpoint") or confess "Couldn't find config";
my $end		= RDF::Endpoint->new( $config );

sub {
    my $env 	= shift;
    my $req 	= Plack::Request->new($env);
    my $resp	= $end->run( $req );
	return $resp->finalize;
}

__END__
