#!perl

use strict;
use warnings;
use Test::More;

use Encode;
use Scalar::Util qw(blessed);
use URI::QueryParam;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common;
use Test::WWW::Mechanize::PSGI;
use Plack::Test;
use RDF::Endpoint;
use RDF::Trine qw(iri);
use RDF::Trine::Namespace;

use constant NEGATIVE_TESTS	=> qw(
	bad_query_method
	bad_multiple_queries
	bad_query_wrong_media_type
	bad_query_missing_form_type
	bad_query_missing_direct_type
	bad_query_non_utf8
	bad_query_syntax
	bad_update_get
	bad_multiple_updates
	bad_update_wrong_media_type
	bad_update_missing_form_type
	bad_update_non_utf8
	bad_update_syntax
	bad_update_dataset_conflict
);

use constant POSITIVE_TESTS => qw(
	query_post_form
	query_get
	query_post_direct
	query_dataset_default_graph
	query_dataset_default_graphs_get
	query_dataset_default_graphs_post
	query_dataset_named_graphs_post
	query_dataset_named_graphs_get
	query_dataset_full
	query_multiple_dataset
	query_content_type_select
	query_content_type_ask
	query_content_type_describe
	query_content_type_construct
	update_dataset_default_graph
	update_dataset_default_graphs
	update_dataset_named_graphs
	update_dataset_full
	update_post_form
	update_post_direct
	update_base_uri
);

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
my $app		= sub {
	my $env 	= shift;
	my $req 	= Plack::Request->new($env);
	my $resp	= $end->run( $req );
	return $resp->finalize;
};
my $mech = Test::WWW::Mechanize::PSGI->new( app => $app );

my $qurl	= 'http://localhost/';
my $uurl	= 'http://localhost/';

positive_requests( $qurl, $uurl, $app );
negative_requests( $qurl, $uurl, $app );
done_testing();
exit;

sub positive_requests {
	my $qurl	= shift;
	my $uurl	= shift;
	my $app		= shift;
	foreach my $t (POSITIVE_TESTS) {
		my $name	= $t;
		$name		=~ tr/-/_/;
		
# 		warn "Positive test: $t\n";
		if (my $cv = __PACKAGE__->can("test_$name")) {
			$cv->($qurl, $uurl, $app, $name);
		} else {
			warn "*** no implementation for test: $name\n";
		}
	}
}

sub negative_requests {
	my $qurl	= shift;
	my $uurl	= shift;
	my $app		= shift;
	my @reqs;
	{
		# bad-query-method - invoke query operation with a method other than GET or POST
		my $req	= PUT("${qurl}?query=ASK%20%7B%7D&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata0.rdf", Content => '');
		push(@reqs, [ 'bad_query_method', $req]);
	}

	{
		#  bad-multiple-queries - invoke query operation with more than one query string
		my $req	= GET("${qurl}?query=ASK%20%7B%7D&query=SELECT%20%2A%20%7B%7D&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata0.rdf");
		push(@reqs, [ 'bad_multiple_queries', $req]);
	}

	{
		#  bad-query-wrong-media-type - invoke query operation with a POST with media type that's not url-encoded or application/sparql-query
		my $req	= POST($qurl, ['default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf'], 'Content-Type' => 'text/plain', Content => 'ASK {}');
		push(@reqs, [ 'bad_query_wrong_media_type', $req]);
	}

	{
		#  bad-query-missing-form-type - invoke query operation with url-encoded body, but without application/x-www-url-form-urlencoded media type
		my $req	= POST($qurl, ['query' => 'ASK {}', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf']);
		$req->remove_header('Content-Type');
		push(@reqs, [ 'bad_query_missing_form_type', $req]);
	}

	{
		#  bad-query-missing-direct-type - invoke query operation with SPARQL body, but without application/sparql-query media type
		my $req	= HTTP::Request->new('POST', $qurl, ['default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf']);
		$req->content('ASK {}');
		push(@reqs, [ 'bad_query_missing_direct_type', $req]);
	}

	{
		#  bad-query-non-utf8 - invoke query operation with direct POST, but with a non-UTF8 encoding (UTF-16)
		my $req	= POST($qurl, ['default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf'], 'Content-Type' => 'application/sparql-query; charset=UTF-16', Content => encode('utf-16', 'ASK {}'));
		push(@reqs, [ 'bad_query_non_utf8', $req]);
	}

	{
		#  bad-query-syntax - invoke query operation with invalid query syntax (4XX result)
		my $req	= GET("${qurl}?query=ASK%20%7B&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata0.rdf");
		push(@reqs, [ 'bad_query_syntax', $req]);
	}
	
	{
		#  bad-update-get - invoke update operation with GET
		my $req	= GET("${uurl}?update=CLEAR%20ALL&using-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata0.rdf");
		push(@reqs, [ 'bad_update_get', $req]);
	}

	{
		#  bad-multiple-updates - invoke update operation with more than one update string
		my $req	= POST($uurl, [ 'update' => 'CLEAR NAMED', 'update' => 'CLEAR DEFAULT', 'using-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
		push(@reqs, [ 'bad_multiple_updates', $req]);
	}

	{
		#  bad-update-wrong-media-type - invoke update operation with a POST with media type that's not url-encoded or application/sparql-update
		my $req	= POST($uurl, ['using-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf'], 'Content-Type' => 'text/plain', Content => 'CLEAR NAMED');
		push(@reqs, [ 'bad_update_wrong_media_type', $req]);
	}

	{
		#  bad-update-missing-form-type - invoke update operation with url-encoded body, but without application/x-www-url-form-urlencoded media type
		my $req	= POST($uurl, [ 'update' => 'CLEAR NAMED', 'using-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
		$req->remove_header('Content-Type');
		push(@reqs, [ 'bad_update_missing_form_type', $req]);
	}

	{
		#  bad-update-non-utf8 - invoke update operation with direct POST, but with a non-UTF8 encoding
		my $req	= POST($uurl, ['using-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf'], 'Content-Type' => 'application/sparql-update; charset=UTF-16', Content => encode('utf-16', 'CLEAR NAMED'));
		push(@reqs, [ 'bad_update_non_utf8', $req]);
	}

	{
		#  bad-update-syntax - invoke update operation with invalid update syntax (4XX result)
		my $req	= POST($uurl, ['update' => 'CLEAR XYZ', 'using-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf']);
		push(@reqs, [ 'bad_update_syntax', $req]);
	}

	{
		#  bad-update-dataset-conflict - invoke update with both using-graph-uri/using-named-graph-uri parameter and USING/WITH clause
		my $update	= <<"END";
PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
WITH <http://example/addresses>
DELETE { ?person foaf:givenName 'Bill' }
INSERT { ?person foaf:givenName 'William' }
WHERE {
?person foaf:givenName 'Bill'
}
END
		my $req	= POST($uurl, ['using-named-graph-uri' => 'http://example/people', 'update' => $update]);
		push(@reqs, [ 'bad_update_dataset_conflict', $req]);
	}

	foreach my $t (@reqs) {
		my ($name, $req)	= @$t;
		test_psgi( app => $app, client => sub {
			my $cb		= shift;
			my $resp	= $cb->($req);
			my $code	= $resp->code;
			like($code, qr/^[45]\d\d/, $name);
		} );
	}
}








sub _test_boolean_result_for_true {
	my $req		= shift;
	my $resp	= shift;
	my $name	= shift;
	my $type	= $resp->header('Content-Type');
	my $content	= $resp->decoded_content;
	my $iter	= ($type =~ /xml/) ? RDF::Trine::Iterator->from_string($content) : RDF::Trine::Iterator->from_json($content);
	my $r		= $iter->next;
	if ($r) {
		pass("$name: true result");
	} else {
		fail("$name: true result");
	}
}

sub _setup_dataset {
	my $uurl	= shift;
	my $app		= shift;
	my $name	= shift;
	my $dgraphs	= shift;
	my $graphs	= shift;
	my @ops		= ('DROP ALL');
	foreach my $g (@$dgraphs) {
		push(@ops, "LOAD <$g>");
	}
	foreach my $g (@$graphs) {
		push(@ops, "LOAD <$g> INTO GRAPH <$g>");
	}
	my $sparql	= join(" ;\n", @ops);
	my $req		= POST($uurl, [
					'update' => $sparql,
				]);

	my $r;
	test_psgi( app => $app, client => sub {
		my $cb		= shift;
		my $resp	= $cb->($req);
		if ($resp->is_success) {
			$r	= 1;
		} else {
			$r	= undef;
		}
	} );
	return $r;
}

sub _test_for_successful_response {
	my $resp	= shift;
	my $name	= shift;
	if ($resp->is_success) {
		return 1;
	} else {
		diag("Got error response " . $resp->code);
		fail($name);
		return 0;
	}
}

sub _run_request {
	my $app	= shift;
	my $req	= shift;
	my $resp;
	test_psgi( app => $app, client => sub {
		my $cb		= shift;
		$resp	= $cb->($req);
	});
	return $resp;
}

sub _test_result_for_select_query {
	my ($req, $resp, $name)	= @_;
	my $type	= $resp->header('Content-Type');
	if ($type =~ m#application/sparql-results[+]xml#) {
		pass($name);
	} elsif ($type =~ m#application/sparql-results[+]json#) {
		pass($name);
	} elsif ($type =~ m#text/tab-separated-values#) {
		pass($name);
	} elsif ($type =~ m#text/csv#) {
		pass($name);
	} else {
		diag("Expected SPARQL Results format appropriate for SELECT form, but got $type");
		fail($name);
	}
}

sub _test_result_for_ask_query {
	my ($req, $resp, $name)	= @_;
	Carp::confess unless (blessed($resp) and $resp->can('header'));
	my $type	= $resp->header('Content-Type');
	if ($type =~ m#application/sparql-results[+]xml#) {
		pass($name);
	} elsif ($type =~ m#application/sparql-results[+]json#) {
		pass($name);
	} else {
		diag("Expected SPARQL Results format appropriate for ASK form, but got $type");
		fail($name);
	}
}

sub _test_result_for_rdf_type {
	my ($req, $resp, $name)	= @_;
	my $type	= $resp->header('Content-Type');
	
	# RDF/XML, Turtle, N-Triples, RDFa
	if ($type =~ m#^((application/rdf[+](xml|json))|(text/turtle))#) {
		pass($name);
	} else {
		diag("Expected RDF Results format, but got $type");
		fail($name);
	}
}





sub test_query_get {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= GET("${qurl}?query=ASK%20%7B%7D&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata0.rdf");
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_post_form {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, ['query' => 'ASK {}', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf']);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_post_direct {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, ['default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf'], 'Content-Type' => 'application/sparql-query', Content => 'ASK {}');
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_default_graph {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf']) or return;
	my $req		= POST($qurl, [
					'query' => 'ASK { <http://kasei.us/2009/09/sparql/data/data1.rdf> ?p ?o }',
					'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data1.rdf'
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_default_graphs_post {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf']) or return;
	my $req		= POST($qurl, [
					'query' => 'ASK { <http://kasei.us/2009/09/sparql/data/data1.rdf> a ?type . <http://kasei.us/2009/09/sparql/data/data2.rdf> a ?type . }',
					'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data1.rdf',
					'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data2.rdf'
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_default_graphs_get {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf']) or return;
	my $req		= GET("${qurl}?query=ASK%20%7B%20%3Chttp%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf%3E%20a%20%3Ftype%20.%20%3Chttp%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf%3E%20a%20%3Ftype%20.%20%7D&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf&default-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf");
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_named_graphs_post {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf']) or return;
	my $req		= POST($qurl, [
					'query' => 'ASK { GRAPH ?g1 { <http://kasei.us/2009/09/sparql/data/data1.rdf> a ?type } GRAPH ?g2 { <http://kasei.us/2009/09/sparql/data/data2.rdf> a ?type } }',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data1.rdf',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data2.rdf'
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_named_graphs_get {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf']) or return;
	my $req		= GET("${qurl}?query=ASK%20%7B%20GRAPH%20%3Fg1%20%7B%20%3Chttp%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf%3E%20a%20%3Ftype%20%7D%20GRAPH%20%3Fg2%20%7B%20%3Chttp%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf%3E%20a%20%3Ftype%20%7D%20%7D&named-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf&named-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf");
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_dataset_full {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf', 'http://kasei.us/2009/09/sparql/data/data3.rdf']) or return;
	my $query	= <<"END";
ASK {
	<http://kasei.us/2009/09/sparql/data/data3.rdf> a ?type
	GRAPH ?g1 { <http://kasei.us/2009/09/sparql/data/data1.rdf> a ?type }
	GRAPH ?g2 { <http://kasei.us/2009/09/sparql/data/data2.rdf> a ?type }
}
END
	my $req		= POST($qurl, [
					'query' => $query,
					'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data3.rdf',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data1.rdf',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data2.rdf'
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_multiple_dataset {
	my ($qurl, $uurl, $app, $name)	= @_;
	_setup_dataset($uurl, $app, $name, [], ['http://kasei.us/2009/09/sparql/data/data1.rdf', 'http://kasei.us/2009/09/sparql/data/data2.rdf', 'http://kasei.us/2009/09/sparql/data/data3.rdf']) or return;
	my $req		= POST($qurl, [
					'query' => 'ASK FROM <http://kasei.us/2009/09/sparql/data/data3.rdf> { GRAPH ?g1 { <http://kasei.us/2009/09/sparql/data/data1.rdf> a ?type } GRAPH ?g2 { <http://kasei.us/2009/09/sparql/data/data2.rdf> a ?type } }',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data1.rdf',
					'named-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data2.rdf'
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		like($type, qr{^application/sparql-results[+](xml|json)$}, $name);
		_test_boolean_result_for_true($req, $resp, $name);
	}
}

sub test_query_content_type_select {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, [ 'query' => 'SELECT (1 AS ?value) {}', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		_test_result_for_select_query( $req, $resp, $name );
	}
}

sub test_query_content_type_ask {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, [ 'query' => 'ASK {}', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		_test_result_for_ask_query( $req, $resp, $name );
	}
}

sub test_query_content_type_describe {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, [ 'query' => 'DESCRIBE <http://example.org/>', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		_test_result_for_rdf_type( $req, $resp, $name );
	}
}

sub test_query_content_type_construct {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($qurl, [ 'query' => 'CONSTRUCT { <s> <p> 1 } WHERE {}', 'default-graph-uri' => 'http://kasei.us/2009/09/sparql/data/data0.rdf' ]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $type	= $resp->header('Content-Type');
		_test_result_for_rdf_type( $req, $resp, $name );
	}
}

sub __________UPDATE_TESTS__________ {}

sub test_update_post_form {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($uurl, [
					'update' => 'CLEAR ALL',
				]);
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		pass($name);
	}
}

sub test_update_post_direct {
	my ($qurl, $uurl, $app, $name)	= @_;
	my $req		= POST($uurl, [], 'Content-Type' => 'application/sparql-update', Content => 'CLEAR ALL');
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		pass($name);
	}
}

sub test_update_base_uri {
	my ($qurl, $uurl, $app, $name)	= @_;
	{
		my $resp	= _run_request( $app, POST($uurl, [
						'update' => 'CLEAR GRAPH <http://example.org/protocol-base-test/> ; INSERT DATA { GRAPH <http://example.org/protocol-base-test/> { <http://example.org/s> <http://example.org/p> <test> } }',
					]) );
	}
	my $req	= POST($qurl, [
						'query' => 'SELECT ?o WHERE { GRAPH <http://example.org/protocol-base-test/> { <http://example.org/s> <http://example.org/p> ?o } }'
					], 'Accept' => 'application/sparql-results+xml');
	my $resp	= _run_request($app, $req);
	if (_test_for_successful_response($resp, $name)) {
		my $content	= $resp->decoded_content;
		my $iter	= RDF::Trine::Iterator->from_string($content);
		my $row		= blessed($iter) ? $iter->next : {};
		my $term	= $row->{'o'};
		if (blessed($term)) {
			my $uri	= $term->uri_value;
			if ($uri eq 'test') {
				diag("No BASE URI was applied to inserted data");
				fail($name);
			} else {
				pass($name);
			}
		} else {
			diag("Failed to retrieve inserted data with subsequent query");
			fail($name);
		}
	}
}

sub test_update_dataset_default_graph {
	my ($qurl, $uurl, $app, $name)	= @_;
	{
		my $sparql	= <<"END";
PREFIX dc: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
CLEAR ALL ;
INSERT DATA {
	GRAPH <http://kasei.us/2009/09/sparql/data/data1.rdf> {
		<http://kasei.us/2009/09/sparql/data/data1.rdf> a foaf:Document
	}
} ;
INSERT {
	GRAPH <http://example.org/protocol-update-dataset-test/> {
		?s a dc:BibliographicResource
	}
}
WHERE {
	?s a foaf:Document
}
END
		my $req		= POST("${uurl}?using-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf", [
						'update' => $sparql,
					]);
		my $resp	= _run_request($app, $req);
		return unless (_test_for_successful_response($resp, $name));
	}
	
	{
		my $sparql	= <<"END";
ASK {
	GRAPH <http://example.org/protocol-update-dataset-test/> {
		<http://kasei.us/2009/09/sparql/data/data1.rdf> a <http://purl.org/dc/terms/BibliographicResource>
	}
}
END
		my $req		= POST($qurl, [], 'Content-Type' => 'application/sparql-query', 'Accept' => 'application/sparql-results+xml', Content => $sparql);
		my $resp	= _run_request($app, $req);
		if (_test_for_successful_response($resp, $name)) {
			my $xmlres	= $resp->decoded_content;
			my $type	= $resp->header('Content-Type');
			if ($type eq 'application/sparql-results+xml') {
				_test_boolean_result_for_true( $req, $resp, $name );
			} else {
				diag("Expected SPARQL XML or JSON results, but got: " . $type);
				fail($name);
			}
		}
	}
}

sub test_update_dataset_default_graphs {
	my ($qurl, $uurl, $app, $name)	= @_;
	{
		my $sparql	= <<"END";
PREFIX dc: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
DROP ALL ;
INSERT DATA {
	GRAPH <http://kasei.us/2009/09/sparql/data/data1.rdf> { <http://kasei.us/2009/09/sparql/data/data1.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data2.rdf> { <http://kasei.us/2009/09/sparql/data/data2.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data3.rdf> { <http://kasei.us/2009/09/sparql/data/data3.rdf> a foaf:Document }
} ;
INSERT {
	GRAPH <http://example.org/protocol-update-dataset-graphs-test/> {
		?s a dc:BibliographicResource
	}
}
WHERE {
	?s a foaf:Document
}
END
		my $req		= POST("${uurl}?using-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf&using-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf", [
						'update' => $sparql,
					]);
		my $resp	= _run_request($app, $req);
		return unless (_test_for_successful_response($resp, $name));
	}
	
	{
		my $sparql	= <<"END";
ASK {
	GRAPH <http://example.org/protocol-update-dataset-graphs-test/> {
		<http://kasei.us/2009/09/sparql/data/data1.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
		<http://kasei.us/2009/09/sparql/data/data2.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
	}
	FILTER NOT EXISTS {
		GRAPH <http://example.org/protocol-update-dataset-graphs-test/> {
			<http://kasei.us/2009/09/sparql/data/data3.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
		}
	}
}
END
		my $req		= POST($qurl, [], 'Content-Type' => 'application/sparql-query', 'Accept' => 'application/sparql-results+xml', Content => $sparql);
		my $resp	= _run_request($app, $req);
		if (_test_for_successful_response($resp, $name)) {
			my $xmlres	= $resp->decoded_content;
			my $type	= $resp->header('Content-Type');
			if ($type eq 'application/sparql-results+xml') {
				_test_boolean_result_for_true( $req, $resp, $name );
			} else {
				diag("Expected SPARQL XML or JSON results, but got: " . $type);
				fail($name);
			}
		}
	}
}

sub test_update_dataset_named_graphs {
	my ($qurl, $uurl, $app, $name)	= @_;
	{
		my $sparql	= <<"END";
PREFIX dc: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
DROP ALL ;
INSERT DATA {
	GRAPH <http://kasei.us/2009/09/sparql/data/data1.rdf> { <http://kasei.us/2009/09/sparql/data/data1.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data2.rdf> { <http://kasei.us/2009/09/sparql/data/data2.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data3.rdf> { <http://kasei.us/2009/09/sparql/data/data3.rdf> a foaf:Document }
} ;
INSERT {
	GRAPH <http://example.org/protocol-update-dataset-named-graphs-test/> {
		?s a dc:BibliographicResource
	}
}
WHERE {
	GRAPH ?g {
		?s a foaf:Document
	}
}
END
		my $req		= POST("${uurl}?using-named-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf&using-named-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf", [
						'update' => $sparql,
					]);
		my $resp	= _run_request($app, $req);
		return unless (_test_for_successful_response($resp, $name));
	}
	
	{
		my $sparql	= <<"END";
ASK {
	GRAPH <http://example.org/protocol-update-dataset-named-graphs-test/> {
		<http://kasei.us/2009/09/sparql/data/data1.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
		<http://kasei.us/2009/09/sparql/data/data2.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
	}
	FILTER NOT EXISTS {
		GRAPH <http://example.org/protocol-update-dataset-named-graphs-test/> {
			<http://kasei.us/2009/09/sparql/data/data3.rdf> a <http://purl.org/dc/terms/BibliographicResource> .
		}
	}
}
END
		my $req		= POST($qurl, [], 'Content-Type' => 'application/sparql-query', 'Accept' => 'application/sparql-results+xml', Content => $sparql);
		my $resp	= _run_request($app, $req);
		if (_test_for_successful_response($resp, $name)) {
			my $xmlres	= $resp->decoded_content;
			my $type	= $resp->header('Content-Type');
			if ($type eq 'application/sparql-results+xml') {
				_test_boolean_result_for_true( $req, $resp, $name );
			} else {
				diag("Expected SPARQL XML or JSON results, but got: " . $type);
				fail($name);
			}
		}
	}
}

sub test_update_dataset_full {
	my ($qurl, $uurl, $app, $name)	= @_;
	{
		my $sparql	= <<"END";
PREFIX dc: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
DROP ALL ;
INSERT DATA {
	GRAPH <http://kasei.us/2009/09/sparql/data/data1.rdf> { <http://kasei.us/2009/09/sparql/data/data1.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data2.rdf> { <http://kasei.us/2009/09/sparql/data/data2.rdf> a foaf:Document }
	GRAPH <http://kasei.us/2009/09/sparql/data/data3.rdf> { <http://kasei.us/2009/09/sparql/data/data3.rdf> a foaf:Document }
} ;
INSERT {
	GRAPH <http://example.org/protocol-update-dataset-full-test/> {
		?s <http://example.org/in> ?in
	}
}
WHERE {
	{
		GRAPH ?g { ?s a foaf:Document }
		BIND(?g AS ?in)
	}
	UNION
	{
		?s a foaf:Document .
		BIND("default" AS ?in)
	}
}
END
		my $req		= POST("${uurl}?using-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata1.rdf&using-named-graph-uri=http%3A%2F%2Fkasei.us%2F2009%2F09%2Fsparql%2Fdata%2Fdata2.rdf", [
						'update' => $sparql,
					]);
		my $resp	= _run_request($app, $req);
		return unless (_test_for_successful_response($resp, $name));
	}
	
	{
		my $sparql	= <<"END";
ASK {
	GRAPH <http://example.org/protocol-update-dataset-full-test/> {
		<http://kasei.us/2009/09/sparql/data/data1.rdf> <http://example.org/in> "default" .
		<http://kasei.us/2009/09/sparql/data/data2.rdf> <http://example.org/in> <http://kasei.us/2009/09/sparql/data/data2.rdf> .
	}
	FILTER NOT EXISTS {
		GRAPH <http://example.org/protocol-update-dataset-full-test/> {
			<http://kasei.us/2009/09/sparql/data/data3.rdf> ?p ?o
		}
	}
}
END
		my $req		= POST($qurl, [], 'Content-Type' => 'application/sparql-query', 'Accept' => 'application/sparql-results+xml', Content => $sparql);
		my $resp	= _run_request($app, $req);
		if (_test_for_successful_response($resp, $name)) {
			my $xmlres	= $resp->decoded_content;
			my $type	= $resp->header('Content-Type');
			if ($type eq 'application/sparql-results+xml') {
				_test_boolean_result_for_true( $req, $resp, $name );
			} else {
				diag("Expected SPARQL XML or JSON results, but got: " . $type);
				fail($name);
			}
		}
	}
}

__END__

