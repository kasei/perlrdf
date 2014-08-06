#!perl

use strict;
use warnings;
use Test::More;

use URI::QueryParam;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common;
use Test::WWW::Mechanize::PSGI;

use RDF::Endpoint;
use RDF::Trine qw(iri);
use RDF::Trine::Namespace;

my $sd	= RDF::Trine::Namespace->new('http://www.w3.org/ns/sparql-service-description#');
my $config	= {
	endpoint	=> {
		endpoint_path   => '/',
		update		=> 1,
		load_data	=> 0,
		html		=> {
			resource_links	=> 1,	# turn resources into links in HTML query result pages
			embed_images	=> 0,	# display foaf:Images as images in HTML query result pages
			image_width		=> 200,	# with 'embed_images', scale images to this width
		},
		service_description	=> {
			default			=> 1,	# generate dataset description of the default graph
			named_graphs	=> 1,	# generate dataset description of the available named graphs
		},
	},
};

my $model	= RDF::Trine::Model->new();
my $end		= RDF::Endpoint->new( $model, $config );
my $mech = Test::WWW::Mechanize::PSGI->new(
	app => sub {
		my $env 	= shift;
		my $req 	= Plack::Request->new($env);
		my $resp	= $end->run( $req );
		return $resp->finalize;
	},
);


{
	my $query	= 'PREFIX : <http://example.org/> SELECT ?o WHERE { :rdf_endpoint_test :p ?o }';
	my $uri		= '/?query=' . uri_escape($query);
	$mech->get_ok($uri, {Accept => 'application/sparql-results+xml'}, 'got success from query GET');
	is( $mech->ct, 'application/sparql-results+xml', 'results are application/sparql-results+xml' );
	my $etag	= $mech->response->header('ETag');
	ok($etag, 'Response has ETag header');
	# Valid ETag syntax is from http://tools.ietf.org/html/rfc7232#section-2.3
	like($etag, qr[^(W/)?"[\x{21}\x{23}-\x{7e}\x{80}-\x{FF}]*"$], 'ETag is properly quoted');
}

done_testing();
