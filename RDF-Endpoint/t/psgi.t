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
	$mech->get_ok('/');
	is( $mech->ct, 'text/html', 'main page text/html' );
	$mech->content_lacks('xmlns:http://www.w3.org/1999/02/22-rdf-syntax-ns#="rdf"', 'No broken NS declaration');
	$mech->content_contains('xmlns:sd="http://www.w3.org/ns/sparql-service-description#"', 'Correct service description NS declaration');
}

{
	$mech->get_ok('/', { Accept => 'application/rdf+xml' });
	is( $mech->ct, 'application/rdf+xml', 'RDF/XML service description' );
	
	my $sd_content	= $mech->content;
	my $sdmodel	= RDF::Trine::Model->new();
	my $e		= 'http://endpoint.local/';
	RDF::Trine::Parser::RDFXML->parse_into_model( $e, $sd_content, $sdmodel );
	ok( $sdmodel->size, 'parsed triples' );
	my @st	= $sdmodel->get_statements( iri($e), $sd->url, undef );
	cmp_ok( scalar(@st), '>', 0, 'expected sd:url triple' );
}

{
	my $query	= "select * where {}";
	my $uri		= '/?query=' . uri_escape($query);
	$mech->get_ok($uri, {Accept => 'application/sparql-results+xml'}, 'got success from empty query');
	is( $mech->ct, 'application/sparql-results+xml', 'SRX media type' );
	my $content	= $mech->content;
	my $i	= RDF::Trine::Iterator->from_string( $content );
	isa_ok( $i, 'RDF::Trine::Iterator::Bindings' );
	my $iter	= $i->materialize;
	is( $iter->length, 1, 'expected result count' );
}

my $before	= $model->size;

{
	my $update	= 'PREFIX : <http://example.org/> INSERT DATA { :rdf_endpoint_test :p "FoooooBAR", 1, _:a }';
	my $resp	= $mech->post_ok('/', { update => $update }, 'got success from insert POST' );
}

my $after	= $model->size;
is( ($after - $before), 3, 'expected model size after INSERT' );

{
	my $query	= 'PREFIX : <http://example.org/> SELECT ?o WHERE { :rdf_endpoint_test :p ?o }';
	my $uri		= '/?query=' . uri_escape($query);
	$mech->get_ok($uri, {Accept => 'application/sparql-results+xml'}, 'got success from query GET');
	my $content	= $mech->content;
	my $iter	= RDF::Trine::Iterator->from_string( $content );
	my @values;
	while (my $r = $iter->next) {
		my $o	= $r->{o};
		if ($o->isa('RDF::Trine::Node::Blank')) {
			push(@values, '_');
		} else {
			push(@values, $o->value);
		}
	}
	is_deeply( [sort @values], [qw(1 FoooooBAR _)], 'expected values after INSERT' );
}

{
	my $query	= 'PREFIX : <http://example.org/> SELECT * WHERE { ?s ?p ?o }';
	$mech->get_ok("/", "Returns 200");
	$mech->title_like(qr/SPARQL/, "Title contains the word SPARQL");
	$mech->submit_form_ok( {
   		  form_id => 'queryform',
		  fields      => {
		   		   query => $query,
				   'media-type' => 'text/html'
				 },
			       }, 'Submitting SELECT query.'
			     );
	$mech->title_like(qr/SPARQL/, "Title contains the word SPARQL");
	$mech->has_tag('textarea', $query, 'Query is in a textarea in the response');
	$mech->has_tag('td', 'FoooooBAR', 'Literal string is in the response');
}


{
	my $update	= 'PREFIX : <http://example.org/> DELETE { :rdf_endpoint_test :p ?o } WHERE { :rdf_endpoint_test ?p ?o }';
	my $resp	= $mech->post_ok('/', { update => $update }, 'got success from delete POST' );
}

{
	my $query	= 'PREFIX : <http://example.org/> SELECT ?o WHERE { :rdf_endpoint_test ?p ?o }';
	my $uri		= '/?query=' . uri_escape($query);
	$mech->get_ok($uri, {Accept => 'application/sparql-results+xml'}, 'got success from query GET');
	my $content	= $mech->content;
	my $iter	= RDF::Trine::Iterator->from_string( $content );
	my $count	= 0;
	while (my $r = $iter->next) {
		$count++;
	}
	is( $count, 0, 'expected count after delete' );
}

done_testing();
