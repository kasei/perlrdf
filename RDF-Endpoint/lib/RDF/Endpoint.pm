=head1 NAME

RDF::Endpoint - A SPARQL Protocol Endpoint implementation

=head1 VERSION

This document describes RDF::Endpoint version 0.05.

=head1 SYNOPSIS

 plackup /usr/local/bin/endpoint.psgi

=head1 DESCRIPTION

This modules implements the SPARQL Protocol for RDF using the PSGI
interface provided by L<Plack>. It may be run with any Plack handler.
See L<Plack::Handler> for more details.

When this module is used to create a SPARQL endpoint, configuration variables
are loaded using L<Config::JFDI>. An example configuration file rdf_endpoint.json
is included with this package. Valid top-level configuration keys include:

=over 4

=item store

This is used to define the underlying L<RDF::Trine::Store> for the
endpoint.  It can be a hashref of the type that can be passed to
L<RDF::Trine::Store>->new_with_config, but a simple string can also be
used.

=item endpoint

A hash of endpoint-specific configuration variables. Valid keys for this hash
include:

=over 8

=item update

A boolean value indicating whether Update operations should be allowed to be
executed by the endpoint.

=item load_data

A boolean value indicating whether the endpoint should use URLs that appear in
FROM and FROM NAMED clauses to construct a SPARQL dataset by dereferencing the
URLs and loading the retrieved RDF content.

=item service_description

An associative array (hash) containing details on which and how much information
to include in the service description provided by the endpoint if no query is
included for execution. The boolean values 'default' and 'named_graphs' indicate
that the respective SPARQL dataset graphs should be described by the service
description.

=item html

An associative array (hash) containing details on how results should be
serialized when the output media type is HTML. The boolean value 'resource_links'
specifies whether URI values should be serialized as HTML anchors (links).
The boolean value 'embed_images' specifies whether URI values that are typed as
foaf:Image should be serialized as HTML images. If 'embed_images' is true, the
integer value 'image_width' specifies the image width to be used in the HTML
markup (letting the image height scale appropriately).

=back

=back

=head1 EXAMPLE CONFIGURATIONS

=head2 Using L<Plack::Handler::Apache2>

Using L<Plack::Handler::Apache2>, mod_perl2 can be configured to serve and
endpoint using the following configuration:

  <Location /sparql>
    SetHandler perl-script
    PerlResponseHandler Plack::Handler::Apache2
    PerlSetVar psgi_app /path/to/endpoint.psgi
    PerlSetEnv RDF_ENDPOINT_CONFIG /path/to/rdf_endpoint.json
  </Location>

To get syntax highlighting and other pretty features, in the
VirtualHost section of your server, add three aliases:

  Alias /js/ /path/to/share/www/js/
  Alias /favicon.ico /path/to/share/www/favicon.ico
  Alias /css/ /path/to/share/www/css/

The exact location can be determined by finding where the file C<sparql_form.js>.

=head1 METHODS

=over 4

=cut

package RDF::Endpoint;

use 5.008;
use strict;
use warnings;
our $VERSION	= '0.05';

use RDF::Query 2.905;
use RDF::Trine 0.134 qw(statement iri blank literal);

use JSON;
use Encode;
use File::Spec;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use XML::LibXML 1.70;
use Plack::Request;
use Plack::Response;
use Scalar::Util qw(blessed refaddr);
use File::ShareDir qw(dist_dir);
use HTTP::Negotiate qw(choose);
use RDF::Trine::Namespace qw(rdf xsd);
use RDF::RDFa::Generator 0.102;
use IO::Compress::Gzip qw(gzip);
use HTML::HTML5::Parser;
use HTML::HTML5::Writer qw(DOCTYPE_XHTML_RDFA);
use Hash::Merge::Simple qw/ merge /;
use Fcntl qw(:flock SEEK_END);
use Carp qw(croak);


my $NAMESPACES	= {
	xsd			=> 'http://www.w3.org/2001/XMLSchema#',
	'format'	=> 'http://www.w3.org/ns/formats/',
	void		=> 'http://rdfs.org/ns/void#',
	scovo		=> 'http://purl.org/NET/scovo#',
	sd			=> 'http://www.w3.org/ns/sparql-service-description#',
	jena		=> 'java:com.hp.hpl.jena.query.function.library.',
	arq			=> 'http://jena.hpl.hp.com/ARQ/function#',
	ldodds		=> 'java:com.ldodds.sparql.',
	fn			=> 'http://www.w3.org/2005/xpath-functions#',
	sparql		=> 'http://www.w3.org/ns/sparql#',
	vann		=> 'http://purl.org/vocab/vann/',
	sde			=> 'http://kasei.us/ns/service-description-extension#',
};

=item C<< new ( \%conf ) >>

=item C<< new ( $model, \%conf ) >>

Returns a new Endpoint object. C<< \%conf >> should be a HASH reference with
configuration settings.

=cut

sub new {
	my $class	= shift;
	my $arg		= shift;
	my ($model, $config);
	if (blessed($arg) and $arg->isa('RDF::Trine::Model')) {
		$model	= $arg;
		$config	= shift;
		delete $config->{store};
	} else {
		$config		= $arg;
		my $store	= RDF::Trine::Store->new( $config->{store} );
		$model		= RDF::Trine::Model->new( $store );
	}
	
	unless ($config->{endpoint}) {
		$config->{endpoint}	= { %$config };
	}
	
	if ($config->{endpoint}{load_data} and $config->{endpoint}{update}) {
		die "The load_data and update configuration options cannot be specified together.";
	}
	
	my $self	= bless( {
		conf		=> $config,
		model		=> $model,
		start_time	=> time,
	}, $class );
	$self->service_description();	# pre-generate the service description
	return $self;
}

=item C<< run ( $req ) >>

Handles the request specified by the supplied Plack::Request object, returning
an appropriate Plack::Response object.

=cut

sub run {
	my $self	= shift;
	my $req		= shift;
	
	my $config	= $self->{conf};
	my $endpoint_path = $config->{endpoint}{endpoint_path} || '/sparql';
	$config->{resource_links}	= 1 unless (exists $config->{resource_links});
	my $model	= $self->{model};
	
	my $content;
	my $response	= Plack::Response->new;
	unless ($req->path eq $endpoint_path) {
		my $path	= $req->path_info;
		$path		=~ s#^/##;
		my $dir		= $ENV{RDF_ENDPOINT_SHAREDIR} || eval { dist_dir('RDF-Endpoint') } || 'share';
		my $file	= File::Spec->catfile($dir, 'www', $path);
		if (-r $file) {
			open( my $fh, '<', $file ) or croak $!;
			$response->status(200);
			$content	= $fh;
		} else {
			my $path	= $req->path;
			$response->status(404);
			$content	= <<"END";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<html><head>\n<title>404 Not Found</title>\n</head><body>\n
<h1>Not Found</h1>\n<p>The requested URL $path was not found on this server.</p>\n</body></html>
END
		}
		$response->body($content);
		return $response;
	}
	
	my $headers	= $req->headers;
	my $type	= $headers->header('Accept') || 'application/sparql-results+xml';
	if (my $t = $req->param('media-type')) {
		$type	= $t;
		$headers->header('Accept' => $type);
	}
	
	my $ae		= $req->headers->header('Accept-Encoding') || '';
	
	my $sparql;
	my $ct	= $req->header('Content-type');
	if ($req->method !~ /^(GET|POST)$/i) {
		my $method	= uc($req->method);
		$content	= "Unexpected method $method (expecting GET or POST)";
		$self->log_error( $req, $content );
		$self->_set_response_error($req, $response, 405, {
			title		=> 'Method not allowed',
			describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/bad_http_method',
		});
		$response->header('Allow' => 'GET, POST');
		goto CLEANUP;
	} elsif (defined($ct) and $ct eq 'application/sparql-query') {
		$sparql	= $req->content;
	} elsif (defined($ct) and $ct eq 'application/sparql-update') {
		if ($config->{endpoint}{update} and $req->method eq 'POST') {
			$sparql	= $req->content;
		}
	} elsif ($req->param('query')) {
		my @sparql	= $req->param('query');
		if (scalar(@sparql) > 1) {
			$content	= "More than one query string submitted";
			$self->log_error( $req, $content );
			$self->_set_response_error($req, $response, 400, {
				title		=> 'Multiple query strings not allowed',
				describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/multiple_queries',
			});
			goto CLEANUP;
		} else {
			$sparql = $sparql[0];
		}
	} elsif ($req->param('update')) {
		my @sparql	= $req->param('update');
		if (scalar(@sparql) > 1) {
			$content	= "More than one update string submitted";
			$self->log_error( $req, $content );
			$self->_set_response_error($req, $response, 400, {
				title		=> 'Multiple update strings not allowed',
				describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/multiple_updates',
			});
			goto CLEANUP;
		}
		
		if ($config->{endpoint}{update} and $req->method eq 'POST') {
			$sparql = $sparql[0];
		} elsif ($req->method ne 'POST') {
			my $method	= $req->method;
			$content	= "Update operations must use POST";
			$self->log_error( $req, $content );
			$self->_set_response_error($req, $response, 405, {
				title		=> "$method Not Allowed for Update Operation",
				describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/bad_http_method_update',
			});
			$response->header('Allow' => 'POST');
			goto CLEANUP;
		}
	}
	
	my $ns = merge $config->{namespaces}, $NAMESPACES;

	if ($sparql) {
		my %args;
		$args{ update }		= 1 if ($config->{endpoint}{update} and $req->method eq 'POST');
		$args{ load_data }	= 1 if ($config->{endpoint}{load_data});
		
		{
			my @default	= $req->param('default-graph-uri');
			my @named	= $req->param('named-graph-uri');
			if (scalar(@default) or scalar(@named)) {
				delete $args{ load_data };
				$model	= RDF::Trine::Model->new( RDF::Trine::Store::Memory->new() );
				foreach my $url (@named) {
					RDF::Trine::Parser->parse_url_into_model( $url, $model, context => iri($url) );
				}
				foreach my $url (@default) {
					RDF::Trine::Parser->parse_url_into_model( $url, $model );
				}
			}
		}
		
		my $protocol_specifies_update_dataset	= 0;
		{
			my @default	= $req->param('using-graph-uri');
			my @named	= $req->param('using-named-graph-uri');
			if (scalar(@named) or scalar(@default)) {
				$protocol_specifies_update_dataset	= 1;
				$model	= RDF::Trine::Model::Dataset->new( $model );
				$model->push_dataset( default => \@default, named => \@named );
			}
		}
		
		my $match	= $headers->header('if-none-match') || '';
		my $etag	= md5_hex( join('#', $self->run_tag, $model->etag, $type, $ae, $sparql) );
		if (length($match)) {
			if (defined($etag) and ($etag eq $match)) {
				$response->status(304);
				return $response;
			}
		}
		
		my $base	= $req->base;
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', base => $base, %args } );
		$self->log_query( $req, $sparql );
		if ($query) {
			if ($protocol_specifies_update_dataset and $query->specifies_update_dataset) {
				my $method	= $req->method;
				$content	= "Update operations cannot specify a dataset in both the query and with protocol parameters";
				$self->log_error( $req, $content );
				$self->_set_response_error($req, $response, 400, {
					title		=> "Multiple datasets specified for update",
					describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/update_specifies_multiple_datasets',
					detail		=> $content,
				});
				goto CLEANUP;
			}
			my ($plan, $ctx)	= $query->prepare( $model );
# 			warn $plan->sse;
			my $iter	= $query->execute_plan( $plan, $ctx );
			if ($iter) {
				$response->status(200);
				if (defined($etag)) {
					$response->headers->header( ETag => $etag );
				}
				if ($iter->isa('RDF::Trine::Iterator::Graph')) {
					my @variants	= (['text/html', 0.99, 'text/html']);
					my %media_types	= %RDF::Trine::Serializer::media_types;
					while (my($type, $sclass) = each(%media_types)) {
						next if ($type =~ /html/);
						my $value	= ($type =~ m#application/rdf[+]xml#) ? 1.00 : 0.98;
						push(@variants, [$type, $value, $type]);
					}
					my $stype	= choose( \@variants, $headers );
					if ($stype !~ /html/ and my $sclass = $RDF::Trine::Serializer::media_types{ $stype }) {
						my $s	= $sclass->new( namespaces => $ns );
						$response->status(200);
						$response->headers->content_type($stype);
						$content	= encode_utf8($s->serialize_iterator_to_string($iter));
					} else {
						$response->headers->content_type( 'text/html' );
						my $html	= $self->iter_as_html($iter, $model);
						$content	= encode_utf8($html);
					}
				} else {
					my @variants	= (
						['text/html', 0.99, 'text/html'],
						['application/sparql-results+xml', 1.0, 'application/sparql-results+xml'],
						['application/json', 0.95, 'application/json'],
						['application/rdf+xml', 0.95, 'application/rdf+xml'],
						['text/turtle', 0.95, 'text/turtle'],
						['text/xml', 0.8, 'text/xml'],
						['application/xml', 0.4, 'application/xml'],
						['text/plain', 0.2, 'text/plain'],
					);
					my $stype	= choose( \@variants, $headers ) || 'application/sparql-results+xml';
					if ($stype =~ /html/) {
						$response->headers->content_type( 'text/html' );
						my $html	= $self->iter_as_html($iter, $model, $sparql);
						$content	= encode_utf8($html);
					} elsif ($stype =~ /xml/) {
						$response->headers->content_type( $stype );
						my $xml		= $self->iter_as_xml($iter, $model);
						$content	= encode_utf8($xml);
					} elsif ($stype =~ /json/) {
						$response->headers->content_type( $stype );
						my $json	= $self->iter_as_json($iter, $model);
						$content	= encode_utf8($json);
					} else {
						$response->headers->content_type( 'text/plain' );
						my $text	= $self->iter_as_text($iter, $model);
						$content	= encode_utf8($text);
					}
				}
			} else {
				my $error	= $query->error;
				$self->_set_response_error($req, $response, 500, {
					title		=> "SPARQL query/update execution error",
					describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/execution_error',
					detail		=> "$error; $sparql",
				});
				$content	= RDF::Query->error;
			}
		} else {
			$content	= RDF::Query->error;
			$self->log_error( $req, $content );
			my $code	= ($content =~ /Syntax/) ? 400 : 500;
			if ($req->method ne 'POST' and $content =~ /read-only queries/sm) {
				$content	= 'Updates must use a HTTP POST request.';
				$self->_set_response_error($req, $response, $code, {
					title		=> $content,
					describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/bad_http_method_update',
				});
			} else {
				$self->_set_response_error($req, $response, $code, {
					title		=> "SPARQL query/update parse error",
					describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/parse_error',
					detail		=> $content,
				});
			}
		}
	} elsif ($req->method eq 'POST') {
		$content	= "POST without recognized query or update";
		$self->log_error( $req, $content );
		$self->_set_response_error($req, $response, 400, {
			title		=> "Missing SPARQL Query/Update String",
			describedby	=> 'http://id.kasei.us/perl/rdf-endpoint/error/missing_sparql_string',
		});
	} else {
		my @variants;
		my %media_types	= %RDF::Trine::Serializer::media_types;
		while (my($type, $sclass) = each(%media_types)) {
			next if ($type =~ /html/);
			push(@variants, [$type, 0.99, $type]);
		}
		push(@variants, ['text/html', 1.0, 'text/html']);
		my $stype	= choose( \@variants, $headers );
		my $sdmodel	= $self->service_description();
		if ($stype !~ /html/ and my $sclass = $RDF::Trine::Serializer::media_types{ $stype }) {
			my $s	= $sclass->new( namespaces => $ns );
			$response->status(200);
			$response->headers->content_type($stype);
			$content	= encode_utf8($s->serialize_model_to_string($sdmodel));
		} else {
			my $dir			= $ENV{RDF_ENDPOINT_SHAREDIR} || eval { dist_dir('RDF-Endpoint') } || 'share';
			my $template	= File::Spec->catfile($dir, 'index.html');
			my $parser		= HTML::HTML5::Parser->new;
			my $doc			= $parser->parse_file( $template );
			my $gen			= RDF::RDFa::Generator->new( style => 'HTML::Head', namespaces => { %$ns } );
			$gen->inject_document($doc, $sdmodel);
			
			my $writer	= HTML::HTML5::Writer->new( markup => 'xhtml', doctype => DOCTYPE_XHTML_RDFA );
			$content	= encode_utf8( $writer->document($doc) );
			$response->status(200);
			$response->headers->content_type('text/html');
		}
	}
	
CLEANUP:
# 	warn Dumper($model);
# 	warn $model->as_string;
	$content	= $response->body || $content;
	my $length	= 0;
	my %ae		= map { $_ => 1 } split(/\s*,\s*/, $ae);
	if ($ae{'gzip'}) {
		my ($rh, $wh);
		pipe($rh, $wh);
		if (ref($content)) {
			gzip $content => $wh;
		} else {
			gzip \$content => $wh;
		}
		close($wh);
		local($/)	= undef;
		my $body	= <$rh>;
		$length		= bytes::length($body);
		$response->headers->header('Content-Encoding' => 'gzip');
		$response->headers->header('Content-Length' => $length);
		$response->body( $body ) unless ($req->method eq 'HEAD');
	} else {
		local($/)	= undef;
		my $body	= ref($content) ? <$content> : $content;
		$length		= bytes::length($body);
		$response->headers->header('Content-Length' => $length);
		$response->body( $body ) unless ($req->method eq 'HEAD');
	}
	return $response;
}

=item C<< run_tag >>

Returns a unique key for each instantiation of this service.

=cut

sub run_tag {
	my $self	= shift;
	return md5_hex(refaddr($self) . $self->{start_time});
}

=item C<< service_description ( $request, $model ) >>

Returns a new RDF::Trine::Model object containing a service description of this
endpoint, generating dataset statistics from C<< $model >>.

=cut

sub service_description {
	my $self		= shift;
	my $model		= $self->{model};
	my $etag		= $model->etag || '';
	
	if (exists $self->{ sd_cache }) {
		my ($cached_etag, $model) = @{ $self->{ sd_cache } };
		if (defined($cached_etag) and $etag eq $cached_etag) {
			return $model;
		}
	}
	
	my $config		= $self->{conf};
	my $doap		= RDF::Trine::Namespace->new('http://usefulinc.com/ns/doap#');
	my $sd			= RDF::Trine::Namespace->new('http://www.w3.org/ns/sparql-service-description#');
	my $sde			= RDF::Trine::Namespace->new('http://kasei.us/ns/service-description-extension#');
	my $vann		= RDF::Trine::Namespace->new('http://purl.org/vocab/vann/');
	my $void		= RDF::Trine::Namespace->new('http://rdfs.org/ns/void#');
	my $scovo		= RDF::Trine::Namespace->new('http://purl.org/NET/scovo#');
	my $count		= $model->count_statements( undef, undef, undef, RDF::Trine::Node::Nil->new );
	
	my @extensions	= grep { !/kasei[.]us/ } RDF::Query->supported_extensions;
	my @functions	= grep { !/kasei[.]us/ } RDF::Query->supported_functions;
	my @formats		= keys %RDF::Trine::Serializer::format_uris;
	
	my $sdmodel		= RDF::Trine::Model->temporary_model;
	my $s			= blank('service');
	$sdmodel->add_statement( statement( $s, $rdf->type, $sd->Service ) );
	
	$sdmodel->add_statement( statement( $s, $sd->supportedLanguage, $sd->SPARQL11Query ) );
	if ($config->{endpoint}{update}) {
		$sdmodel->add_statement( statement( $s, $sd->supportedLanguage, $sd->SPARQL11Update ) );
	}
	if ($config->{endpoint}{load_data}) {
		$sdmodel->add_statement( statement( $s, $sd->feature, $sd->DereferencesURIs ) );
	}
	
	foreach my $ext (@extensions) {
		$sdmodel->add_statement( statement( $s, $sd->languageExtension, iri($ext) ) );
	}
	foreach my $func (@functions) {
		$sdmodel->add_statement( statement( $s, $sd->extensionFunction, iri($func) ) );
	}
	
	$sdmodel->add_statement( statement( $s, $sd->resultFormat, iri('http://www.w3.org/ns/formats/SPARQL_Results_XML') ) );
	$sdmodel->add_statement( statement( $s, $sd->resultFormat, iri('http://www.w3.org/ns/formats/SPARQL_Results_JSON') ) );
	foreach my $format (@formats) {
		$sdmodel->add_statement( statement( $s, $sd->resultFormat, iri($format) ) );
	}
	
	my $dataset		= blank('dataset');
	$sdmodel->add_statement( statement( $s, $sd->endpoint, iri('') ) );
	$sdmodel->add_statement( statement( $s, $sd->defaultDataset, $dataset ) );
	$sdmodel->add_statement( statement( $dataset, $rdf->type, $sd->Dataset ) );
	if (my $d = $config->{endpoint}{service_description}{default}) {
		my $def_graph	= ($d =~ /^\w+:/) ? iri($d) : blank('defaultGraph');
		$sdmodel->add_statement( statement( $dataset, $sd->defaultGraph, $def_graph ) );
		$sdmodel->add_statement( statement( $def_graph, $rdf->type, $sd->Graph ) );
		$sdmodel->add_statement( statement( $def_graph, $rdf->type, $void->Dataset ) );
		$sdmodel->add_statement( statement( $def_graph, $void->triples, literal( $count, undef, $xsd->integer ) ) );
	}
	if ($config->{endpoint}{service_description}{named_graphs}) {
		my $iter	= $model->get_contexts;
		while (my $g = $iter->next) {
			my $ng		= blank();
			my $graph	= blank();
			my $count	= $model->count_statements( undef, undef, undef, $g );
			$sdmodel->add_statement( statement( $dataset, $sd->namedGraph, $ng ) );
			$sdmodel->add_statement( statement( $ng, $sd->name, $g ) );
			$sdmodel->add_statement( statement( $ng, $sd->graph, $graph ) );
			$sdmodel->add_statement( statement( $graph, $rdf->type, $sd->Graph ) );
			$sdmodel->add_statement( statement( $graph, $rdf->type, $void->Dataset ) );
			$sdmodel->add_statement( statement( $graph, $void->triples, literal( $count, undef, $xsd->integer ) ) );
		}
	}
	
	if (my $software = $config->{endpoint}{service_description}{software}) {
		$sdmodel->add_statement( statement( $s, $sde->software, iri($software) ) );
	}
	
	if (my $related = $config->{endpoint}{service_description}{related}) {
		foreach my $r (@$related) {
			$sdmodel->add_statement( statement( $s, $sde->relatedEndpoint, iri($r) ) );
		}
	}
	
	if (my $namespaces = $config->{endpoint}{service_description}{namespaces}) {
		while (my($ns,$uri) = each(%$namespaces)) {
			my $b	= RDF::Trine::Node::Blank->new();
			$sdmodel->add_statement( statement( $s, $sde->namespace, $b ) );
			$sdmodel->add_statement( statement( $b, $vann->preferredNamespacePrefix, literal($ns) ) );
			$sdmodel->add_statement( statement( $b, $vann->preferredNamespaceUri, literal($uri) ) );
		}
	}
	
	$self->{ sd_cache }	= [ $etag, $sdmodel ];
	return $sdmodel;
}

=begin private

=item C<< iter_as_html ( $iter, $model ) >>

=cut

sub iter_as_html {
	my $self	= shift;
	my $stream	= shift;
	my $model	= shift;
	my $query	= shift;

	my $dir  = $ENV{RDF_ENDPOINT_SHAREDIR} || eval { dist_dir('RDF-Endpoint') } || 'share';
	my $file = File::Spec->catfile($dir, 'results.html');
	my $html;

	if (-r $file) {
		open( my $fh, '<', $file ) or croak $!;
		$html = do { local $/; <$fh>; };
		close $fh;
	} else {
		$html = <<HTML
<html><head><title>SPARQL Results</title></head><body>
<div id="result" />
<h2>Query</h2> 
<form id="queryform" action="" method="get"> 
<p><textarea id="query" name="query" rows="10" cols="60"></textarea>
<br/>
<select id="media-type" name="media-type"> 
    <option value="">Result Format...</option> 
    <option label="HTML" value="text/html">HTML</option> 
    <option label="Turtle" value="text/turtle">Turtle</option> 
    <option label="XML" value="text/xml">XML</option> 
    <option label="JSON" value="application/json">JSON</option> 
</select> 
<input name="submit" id="submit" type="submit" value="Submit" /> 
</p>
</form>
</body></html>
HTML
	}

	my $result = "<h2>Result</h2>\n";

	if ($stream->isa('RDF::Trine::Iterator::Boolean')) {
		$result	= (($stream->get_boolean) ? "True" : "False");
	} elsif ($stream->isa('RDF::Trine::Iterator::Bindings')) {
		$result = "<table class='tablesorter'>\n<thead><tr>\n";
		
		my @names	= $stream->binding_names;
		my $columns	= scalar(@names);
		foreach my $name (@names) {
			$result	.= "\t<th>" . $name . "</th>\n";
		}
		$result	.= "</tr></thead>\n";
		
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			$result	.= "<tr>\n";
			foreach my $k (@names) {
				my $node	= $row->{ $k };
				my $value	= $self->node_as_html($node, $model);
				$result	.= "\t<td>" . $value . "</td>\n";
			}
			$result	.= "</tr>\n";
		}
		$result   .= "<tfoot><tr><th colspan=\"$columns\">Total: $count</th></tr></tfoot>\n</table>\n";	
	}

	$html =~ s/<div\s+id\s*=\s*["']result["']\s*\/>/<div id="result">$result<\/div>/;
	$html =~ s/(<textarea[^>]*>)(.|\n)*(<\/textarea>)/$1$query$3/sm;

	return $html;
}

=item C<< iter_as_text ( $iter ) >>

=cut

sub iter_as_text {
	my $self	= shift;
	my $iter	= shift;
	if ($iter->isa('RDF::Trine::Iterator::Graph')) {
		my $serializer	= RDF::Trine::Serializer->new('ntriples');
		return $serializer->serialize_iterator_to_string( $iter );
	} else {
		return $iter->as_string;
	}
}

=item C<< iter_as_xml ( $iter ) >>

=cut

sub iter_as_xml {
	my $self	= shift;
	my $iter	= shift;
	return $iter->as_xml;
}

=item C<< iter_as_json ( $iter ) >>

=cut

sub iter_as_json {
	my $self	= shift;
	my $iter	= shift;
	return $iter->as_json;
}

=item C<< node_as_html ( $node, $model ) >>

=cut

sub node_as_html {
	my $self	= shift;
	my $node	= shift;
	my $model	= shift;
	my $config	= $self->{conf};
	return '' unless (blessed($node));
	if ($node->isa('RDF::Trine::Node::Resource')) {
		my $uri	= $node->uri_value;
		for ($uri) {
			s/&/&amp;/g;
			s/</&lt;/g;
		}
		my $link	= $config->{endpoint}{html}{resource_links};
		my $html;
		if ($config->{endpoint}{html}{embed_images}) {
			if ($model->count_statements( $node, iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri('http://xmlns.com/foaf/0.1/Image') )) {
				my $width	= $config->{endpoint}{html}{image_width} || 200;
				$html	= qq[<img src="${uri}" width="${width}" />];
			} else {
				$html	= $uri;
			}
		} else {
			$html	= $uri;
		}
		if ($link) {
			$html	= qq[<a href="${uri}">$html</a>];
		}
		return $html;
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $html	= $node->literal_value;
		for ($html) {
			s/&/&amp;/g;
			s/</&lt;/g;
		}
		return $html;
	} else {
		my $html	= $node->as_string;
		for ($html) {
			s/&/&amp;/g;
			s/</&lt;/g;
		}
		return $html;
	}
}

=item C<< log_query ( $message ) >>

=cut

sub log_query {
	my $self	= shift;
	my $req		= shift;
	my $message	= shift;
	$self->_log( $req, { level => 'info', message => $message } );
}

=item C<< log_error ( $message ) >>

=cut

sub log_error {
	my $self	= shift;
	my $req		= shift;
	my $message	= shift;
	$self->_log( $req, { level => 'error', message => $message } );
}

sub _log {
	my $self	= shift;
	my $req		= shift;
	my $data	= shift;
	my $logger	= $req->logger || sub {};
	
	$logger->($data);
}

sub _set_response_error {
	my $self	= shift;
	my $req		= shift;
	my $resp	= shift;
	my $code	= shift;
	my $error	= shift;
	my @variants	= (
		['text/plain', 1.0, 'text/plain'],
		['application/json-problem', 0.99, 'application/json-problem'],
	);
	my $headers	= $req->headers;
	my $stype	= choose( \@variants, $headers ) || 'text/plain';
	if ($stype eq 'application/json-problem') {
		$resp->headers->content_type( 'application/json-problem' );
		$resp->status($code);
		my $content	= encode_json($error);
		$resp->body($content);
	} else {
		$resp->headers->content_type( 'text/plain' );
		$resp->status($code);
		my @messages	= grep { defined($_) } @{ $error }{ qw(title detail) };
		my $content		= join("\n\n", @messages);
		$resp->body($content);
	}
	return;
}

=end private

=cut

1;

__END__

=back

=head1 SEE ALSO

=over 4

=item * L<http://www.w3.org/TR/sparql11-protocol/>

=item * L<http://www.perlrdf.org/>

=item * L<irc://irc.perl.org/#perlrdf>

=item * L<http://codemirror.net/>

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010-2012 Gregory Todd Williams.

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any
damages arising from the use of this software.

Permission is granted to anyone to use this software for any
purpose, including commercial applications, and to alter it and
redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must
   not claim that you wrote the original software. If you use this
   software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source
   distribution.

With the exception of the CodeMirror files, the files in this package may also
be redistributed and/or modified under the same terms as Perl itself.

The CodeMirror (Javascript and CSS) files contained in this package are
copyright (c) 2007-2010 Marijn Haverbeke, and licensed under the terms of the
same zlib license as this code.

=cut
