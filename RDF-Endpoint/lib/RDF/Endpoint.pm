=head1 NAME

RDF::Endpoint - A SPARQL Protocol Endpoint implementation

=head1 VERSION

This document describes RDF::Endpoint version 0.02.

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

A string used to define the underlying L<RDF::Trine::Store> for the endpoint.
The string is used as the argument to the L<RDF::Trine::Store->new_with_string>
constructor.

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

=head1 METHODS

=over 4

=cut

package RDF::Endpoint;

use 5.008;
use strict;
use warnings;
our $VERSION	= '0.02';

use RDF::Query 2.905;
use RDF::Trine 0.134 qw(statement iri blank literal);

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
use RDF::RDFa::Generator;
use IO::Compress::Gzip qw(gzip);
use HTML::HTML5::Parser;
use HTML::HTML5::Writer qw(DOCTYPE_XHTML_RDFA);

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
		my $store	= RDF::Trine::Store->new_with_string( $config->{store} );
		$model		= RDF::Trine::Model->new( $store );
	}
	unless ($config->{endpoint}) {
		$config->{endpoint}	= { %$config };
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
	$config->{resource_links}	= 1 unless (exists $config->{resource_links});
	my $model	= $self->{model};
	
	my $content;
	my $response	= Plack::Response->new;
	unless ($req->path eq '/') {
		my $path	= $req->path_info;
		$path		=~ s#^/##;
		my $dir		= $ENV{RDF_ENDPOINT_SHAREDIR} || eval { dist_dir('RDF-Endpoint') } || 'share';
		my $file	= File::Spec->catfile($dir, 'www', $path);
		if (-r $file) {
			open( my $fh, '<', $file ) or die $!;
			$response->status(200);
			$content	= $fh;
		} else {
			$response->status(404);
			$content	= <<"END";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<html><head>\n<title>404 Not Found</title>\n</head><body>\n
<h1>Not Found</h1>\n<p>The requested URL was not found on this server.</p>\n</body></html>
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
	if (defined($ct) and $ct eq 'application/sparql-query') {
		$sparql	= $req->content;
	} elsif (defined($ct) and $ct eq 'application/sparql-update') {
		if ($config->{endpoint}{update} and $req->method eq 'POST') {
			$sparql	= $req->content;
		}
	} elsif ($req->param('query')) {
		$sparql = $req->param('query');
	} elsif ($req->param('update')) {
		if ($config->{endpoint}{update} and $req->method eq 'POST') {
			$sparql = $req->param('update');
		}
	}
	
	if ($sparql) {
		my %args;
		$args{ update }		= 1 if ($config->{endpoint}{update} and $req->method eq 'POST');
		$args{ load_data }	= 1 if ($config->{endpoint}{load_data});
		
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
		if ($query) {
			my ($plan, $ctx)	= $query->prepare( $model );
# 			warn $plan->sse;
			my $iter	= $query->execute_plan( $plan, $ctx );
			if ($iter) {
				$response->status(200);
				if (defined($etag)) {
					$response->headers->header( ETag => $etag );
				}
				if ($iter->isa('RDF::Trine::Iterator::Graph')) {
					my @variants	= (['text/html', 1.0, 'text/html']);
					my %media_types	= %RDF::Trine::Serializer::media_types;
					while (my($type, $sclass) = each(%media_types)) {
						next if ($type =~ /html/);
						push(@variants, [$type, 0.99, $type]);
					}
					my $stype	= choose( \@variants, $headers );
					if ($stype !~ /html/ and my $sclass = $RDF::Trine::Serializer::media_types{ $stype }) {
						my $s	= $sclass->new( namespaces => $NAMESPACES );
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
				$response->status(500);
				$content	= RDF::Query->error;
			}
		} else {
			$content	= RDF::Query->error;
			my $code	= ($content =~ /Syntax/) ? 400 : 500;
			$response->status($code);
			if ($req->method ne 'POST' and $content =~ /read-only queries/sm) {
				$content	= 'Updates must use a HTTP POST request.';
			}
			warn $content;
		}
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
			my $s	= $sclass->new( namespaces => $NAMESPACES );
			$response->status(200);
			$response->headers->content_type($stype);
			$content	= encode_utf8($s->serialize_model_to_string($sdmodel));
		} else {
			my $dir			= $ENV{RDF_ENDPOINT_SHAREDIR} || eval { dist_dir('RDF-Endpoint') } || 'share';
			my $template	= File::Spec->catfile($dir, 'index.html');
			my $parser		= HTML::HTML5::Parser->new;
			my $doc			= $parser->parse_file( $template );
			my $gen			= RDF::RDFa::Generator->new( style => 'HTML::Head', ns => { reverse %$NAMESPACES } );
			$gen->inject_document($doc, $sdmodel);
			
			my $writer	= HTML::HTML5::Writer->new( markup => 'xhtml', doctype => DOCTYPE_XHTML_RDFA );
			$content	= encode_utf8( $writer->document($doc) );
			$response->status(200);
			$response->headers->content_type('text/html');
		}
	}
	
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
	my $sd			= RDF::Trine::Namespace->new('http://www.w3.org/ns/sparql-service-description#');
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
	foreach my $format (@formats) {
		$sdmodel->add_statement( statement( $s, $sd->resultFormat, iri($format) ) );
	}
	
	my $dataset		= blank('dataset');
	my $def_graph	= blank('defaultGraph');
	$sdmodel->add_statement( statement( $s, $sd->url, iri('') ) );
	$sdmodel->add_statement( statement( $s, $sd->defaultDatasetDescription, $dataset ) );
	$sdmodel->add_statement( statement( $dataset, $rdf->type, $sd->Dataset ) );
	if ($config->{endpoint}{service_description}{default}) {
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
	my $html	= "<html><head><title>SPARQL Results</title>\n"
				. <<"END";
	<link rel="stylesheet" type="text/css" href="/css/docs.css"/>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js" type="text/javascript"></script>
    <script src="/js/codemirror.js" type="text/javascript"></script>
	<script type="text/javascript" src="/js/sparql_form.js"></script>
	<style type="text/css">
		table {
			border: 1px solid #000;
			border-collapse: collapse;
		}
		
		th { background-color: #ddd; }
		td, th {
			padding: 1px 5px 1px 5px;
			border: 1px solid #000;
		}
	</style>
</head><body>
	<h2>Results</h2>
END
	if ($stream->isa('RDF::Trine::Iterator::Boolean')) {
		$html	.= (($stream->get_boolean) ? "True" : "False");
	} elsif ($stream->isa('RDF::Trine::Iterator::Bindings')) {
		$html	.= "<table>\n<tr>\n";
		
		my @names	= $stream->binding_names;
		my $columns	= scalar(@names);
		foreach my $name (@names) {
			$html	.= "\t<th>" . $name . "</th>\n";
		}
		$html	.= "</tr>\n";
		
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			$html	.= "<tr>\n";
			foreach my $k (@names) {
				my $node	= $row->{ $k };
				my $value	= $self->node_as_html($node, $model);
				$html	.= "\t<td>" . $value . "</td>\n";
			}
			$html	.= "</tr>\n";
		}
		$html	.= <<"END";
		<tr><th colspan="$columns">Total: $count</th></tr>
	</table>
	<h2>Query</h2>
	<form id="queryform" action="" method="get">
	<p>
		<textarea id="query" name="query" rows="10" cols="60">${query}</textarea><br/>
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
END
	} else {
		
	}
	$html	.= <<"END";
<style type="text/css">
<!--
tbody tr:nth-child(odd) {
	background-color: #eeeefa;
	border-bottom: 1px solid #dddde9;
	border-top: 1px solid #dddde9;
}

th {
	background-color: #ddf;
	border-bottom: 2px solid #000;
}
// -->
</style>
</body></html>
END
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

=end private

=cut

1;

__END__

=back

=head1 SEE ALSO

=over 4

=item * L<http://www.w3.org/TR/rdf-sparql-protocol/>

=item * L<http://www.perlrdf.org/>

=item * L<irc://irc.perl.org/#perlrdf>

=item * L<http://codemirror.net/>

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Gregory Todd Williams.

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
