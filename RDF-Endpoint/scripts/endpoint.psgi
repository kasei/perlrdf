#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Plack::Request;
use Plack::Builder;
use Config::ZOMG;
use Carp qw(confess);
use RDF::Endpoint;
use LWP::MediaTypes qw(add_type);

add_type( 'application/rdf+xml' => qw(rdf xrdf rdfx) );
add_type( 'text/turtle' => qw(ttl) );
add_type( 'text/plain' => qw(nt) );
add_type( 'text/x-nquads' => qw(nq) );
add_type( 'text/json' => qw(json) );
add_type( 'text/html' => qw(html xhtml htm) );

my $config;
if (my $file = $ENV{RDF_ENDPOINT_FILE}) {
	my $abs	= File::Spec->rel2abs( $file );
	$config	= {
		store	=> "Memory;file://$abs",
		endpoint	=> {
			service_description => {
				named_graphs	=> 1,
				default			=> 1,
			},
			html				=> {
				embed_images	=> 1,
				image_width		=> 200,
				resource_links	=> 1,
			},
			load_data	=> 0,
			update		=> 1,
        }
    };
} elsif ($config = eval { Config::ZOMG->open( name => "RDF::Endpoint") }) {
} else {
	$config	= {
		store	=> "Memory",
		endpoint	=> {
			service_description => {
				named_graphs	=> 1,
				default			=> 1,
			},
			html				=> {
				embed_images	=> 1,
				image_width		=> 200,
				resource_links	=> 1,
			},
			load_data	=> 0,
			update		=> 1,
        }
    };
}

if (exists $ENV{'PERLRDF_STORE'}) {
	$config->{store} = $ENV{'PERLRDF_STORE'};
}

my $end		= RDF::Endpoint->new( $config );

my $app	= sub {
    my $env 	= shift;
    my $req 	= Plack::Request->new($env);
    my $resp	= $end->run( $req );
	return $resp->finalize;
};

builder {
	enable "AccessLog", format => "combined";
	$app;
};

__END__
