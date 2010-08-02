=head1 NAME

RDF::Endpoint - A SPARQL Protocol Endpoint implementation

=head1 VERSION

This document describes RDF::Endpoint version 0.01_03.

=head1 SYNOPSIS

 plackup /usr/local/bin/endpoint.psgi

=head1 DESCRIPTION

This modules implements the SPARQL Protocol for RDF using the PSGI
interface provided by L<Plack>. It may be run with any Plack handler.
See L<Plack::Handler> for more details.

When this module is used to create a SPARQL endpoint, configuration variables
are loaded using L<Config::JFDI>. An example configuration file rdf_endpoint.json
is included with this package. Valid configuration keys include:

=over 4

=item store

A string used to define the underlying L<RDF::Trine::Store> for the endpoint.
The string is used as the argument to the L<RDF::Trine::Store->new_with_string>
constructor.

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
our $VERSION	= '0.01';

use RDF::Query 2.900;
use RDF::Trine 0.124 qw(statement iri blank literal);

use Encode;
use File::Spec;
use XML::LibXML 1.70;
use Plack::Request;
use Plack::Response;
use Scalar::Util qw(blessed);
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
	ldodds		=> 'java:com.ldodds.sparql.',
};

=item C<< new ( $conf ) >>

Returns a new Endpoint object. C<< $conf >> should be a HASH reference with
configuration settings.

=cut

sub new {
	my $class	= shift;
	my $conf	= shift;
	return bless( { conf => $conf }, $class );
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
	
	
	my $store	= RDF::Trine::Store->new_with_string( $config->{store} );
	my $model	= RDF::Trine::Model->new( $store );
	
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
		return $response;
	}
	
	
	my $headers	= $req->headers;
	if (my $type = $req->param('media-type')) {
		$headers->header('Accept' => $type);
	}
	
	if (my $sparql = $req->param('query')) {
		my %args;
		$args{ update }		= 1 if ($config->{update} and $req->method eq 'POST');
		$args{ load_data }	= 1 if ($config->{load_data});
		
		my @default	= $req->param('default-graph-uri');
		my @named	= $req->param('named-graph-uri');
		if (scalar(@default) or scalar(@named)) {
			delete $args{ load_data };
			$model	= RDF::Trine::Model->temporary_model;
			foreach my $url (@named) {
				RDF::Trine::Parser->parse_url_into_model( $url, $model, context => iri($url) );
			}
			foreach my $url (@default) {
				RDF::Trine::Parser->parse_url_into_model( $url, $model );
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
						['text/html', 1.0, 'text/html'],
						['text/plain', 0.9, 'text/plain'],
						['application/json', 0.95, 'application/json'],
						['application/rdf+xml', 0.95, 'application/rdf+xml'],
						['text/turtle', 0.95, 'text/turtle'],
						['application/xml', 0.9, 'application/xml'],
						['text/xml', 0.9, 'text/xml'],
						['application/sparql-results+xml', 0.99, 'application/sparql-results+xml'],
					);
					my $stype	= choose( \@variants, $headers ) || 'text/html';
					if ($stype =~ /html/) {
						$response->headers->content_type( 'text/html' );
						my $html	= $self->iter_as_html($iter, $model);
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
		my $sdmodel	= $self->service_description( $req, $model );
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
			my $gen			= RDF::RDFa::Generator->new( style => 'HTML::Head', ns => $NAMESPACES );
			$gen->inject_document($doc, $sdmodel);
			
			my $writer	= HTML::HTML5::Writer->new( markup => 'xhtml', doctype => DOCTYPE_XHTML_RDFA );
			$content	= encode_utf8( $writer->document($doc) );
			$response->status(200);
			$response->headers->content_type('text/html');
		}
	}
	
	my $length	= 0;
	my $ae		= $req->headers->header('Accept-Encoding') || '';
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

=item C<< service_description ( $request, $model ) >>

Returns a new RDF::Trine::Model object containing a service description of this
endpoint, generating dataset statistics from C<< $model >>.

=cut

sub service_description {
	my $self	= shift;
	my $req		= shift;
	my $model	= shift;
	my $config	= $self->{conf};
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
	if ($config->{update}) {
		$sdmodel->add_statement( statement( $s, $sd->supportedLanguage, $sd->SPARQL11Update ) );
	}
	if ($config->{load_data}) {
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
	
	my $dsd	= blank('dataset');
	my $def	= blank('defaultGraph');
	my $si	= blank('size');
	$sdmodel->add_statement( statement( $s, $sd->url, iri('') ) );
	$sdmodel->add_statement( statement( $s, $sd->defaultDatasetDescription, $dsd ) );
	$sdmodel->add_statement( statement( $dsd, $rdf->type, $sd->Dataset ) );
	if ($config->{service_description}{default}) {
		$sdmodel->add_statement( statement( $dsd, $sd->defaultGraph, $def ) );
		$sdmodel->add_statement( statement( $def, $void->statItem, $si ) );
		$sdmodel->add_statement( statement( $si, $scovo->dimension, $void->numberOfTriples ) );
		$sdmodel->add_statement( statement( $si, $rdf->value, literal( $count, undef, $xsd->integer->uri_value ) ) );
	}
	if ($config->{service_description}{named_graphs}) {
		my $iter	= $model->get_contexts;
		while (my $g = $iter->next) {
			my $ng		= blank();
			my $graph	= blank();
			my $si		= blank();
			my $count	= $model->count_statements( undef, undef, undef, $g );
			$sdmodel->add_statement( statement( $dsd, $sd->namedGraph, $ng ) );
			$sdmodel->add_statement( statement( $ng, $sd->name, $g ) );
			$sdmodel->add_statement( statement( $ng, $sd->graph, $graph ) );
			$sdmodel->add_statement( statement( $graph, $void->statItem, $si ) );
			$sdmodel->add_statement( statement( $si, $scovo->dimension, $void->numberOfTriples ) );
			$sdmodel->add_statement( statement( $si, $rdf->value, literal( $count, undef, $xsd->integer->uri_value ) ) );
		}
	}
	return $sdmodel;
}

=begin private

=item C<< iter_as_html ( $iter, $model ) >>

=cut

sub iter_as_html {
	my $self	= shift;
	my $stream	= shift;
	my $model	= shift;
	my $html	= "<html><head><title>SPARQL Results</title>\n"
				. <<"END";
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
END
		$html	.= "</head><body>\n";
	if ($stream->isa('RDF::Trine::Iterator::Graph')) {
		$html	.= "<table>\n<tr>\n";
		
		my @names	= qw(subject predicate object);
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
				my $node	= $row->$k();
				my $value	= $self->node_as_html($node, $model);
				$html	.= "\t<td>" . $value . "</td>\n";
			}
			$html	.= "</tr>\n";
		}
		$html	.= qq[<tr><th colspan="$columns">Total: $count</th></tr>];
		$html	.= "</table>\n";
	} elsif ($stream->isa('RDF::Trine::Iterator::Boolean')) {
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
		$html	.= qq[<tr><th colspan="$columns">Total: $count</th></tr>];
		$html	.= "</table>\n";
	} else {
		
	}
	$html	.= "</body></html>\n";
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
		my $link	= $config->{html}{resource_links};
		my $html;
		if ($config->{html}{embed_images}) {
			if ($model->count_statements( $node, iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri('http://xmlns.com/foaf/0.1/Image') )) {
				my $width	= $config->{html}{image_width} || 200;
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

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
