=head1 NAME

RDF::Endpoint - A SPARQL Protocol Endpoint implementation

=head1 VERSION

This document describes RDF::Endpoint version 0.01, released XX XXXX 2010.

=cut

package RDF::Endpoint;

use 5.008;
use strict;
use warnings;
our $VERSION	= '0.01_01';

use RDF::Query;
use RDF::Trine qw(statement iri blank literal);

use Encode;
use File::Spec;
use XML::LibXML 1.70;
use Plack::Request;
use Plack::Response;
use File::ShareDir qw(dist_dir);
use HTTP::Negotiate qw(choose);
use RDF::Trine::Namespace qw(rdf xsd);
use RDF::RDFa::Generator;
use IO::Compress::Gzip qw(gzip);

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
	
	my $store	= RDF::Trine::Store->new_with_string( $config->{store} );
	my $model	= RDF::Trine::Model->new( $store );
	
	my $content;
	my $response	= Plack::Response->new;
	unless ($req->path eq '/') {
		my $path	= $req->path_info;
		$path		=~ s#^/##;
		my $dir		= eval { dist_dir('RDF-Endpoint') } || 'share';
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
		my @variants	= (
			['text/html', 1.0, 'text/html'],
			['text/plain', 0.9, 'text/plain'],
			['application/json', 1.0, 'application/json'],
			['application/xml', 0.9, 'application/xml'],
			['text/xml', 0.9, 'text/xml'],
			['application/sparql-results+xml', 1.0, 'application/sparql-results+xml'],
		);
		my $stype	= choose( \@variants, $headers ) || 'text/html';
		my %args;
		$args{ update }		= 1 if ($config->{update} and $req->method eq 'POST');
		$args{ load_data }	= 1 if ($config->{load_data});
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', %args } );
		
		if ($query) {
			my $iter	= $query->execute( $model );
			if ($iter) {
				$response->status(200);
				if ($stype =~ /html/) {
					$response->headers->content_type( 'text/plain' );
					$content	= encode_utf8($iter->as_string);
				} elsif ($stype =~ /xml/) {
					$response->headers->content_type( $stype );
					$content	= encode_utf8($iter->as_xml);
				} elsif ($stype =~ /json/) {
					$response->headers->content_type( $stype );
					$content	= encode_utf8($iter->as_json);
				} else {
					$response->headers->content_type( 'text/plain' );
					$content	= encode_utf8($iter->as_string);
				}
			} else {
				$response->status(500);
				$content	= RDF::Query->error;
			}
		} else {
			$response->status(500);
			$content	= RDF::Query->error;
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
			push(@variants, [$type, 1.0, $type]);
		}
		
		my $ns	= {
			xsd		=> 'http://www.w3.org/2001/XMLSchema#',
			void	=> 'http://rdfs.org/ns/void#',
			scovo	=> 'http://purl.org/NET/scovo#',
			sd		=> 'http://www.w3.org/ns/sparql-service-description#',
			jena	=> 'java:com.hp.hpl.jena.query.function.library.',
			ldodds	=> 'java:com.ldodds.sparql.',
			kasei	=> 'http://kasei.us/2007/09/functions/',
		};
		push(@variants, ['text/html', 1.0, 'text/html']);
		my $stype	= choose( \@variants, $headers );
		my $sdmodel	= $self->service_description( $req, $model );
		if ($stype !~ /html/ and my $sclass = $RDF::Trine::Serializer::media_types{ $stype }) {
			my $s	= $sclass->new( namespaces => $ns );
			$response->status(200);
			$response->headers->content_type($stype);
			$content	= encode_utf8($s->serialize_model_to_string($sdmodel));
		} else {
			my $dir			= eval { dist_dir('RDF-Endpoint') } || 'share';
			my $template	= File::Spec->catfile($dir, 'index.html');
			my $parser		= XML::LibXML->new();
			my $doc			= $parser->load_html( location => $template );
			my $gen			= RDF::RDFa::Generator->new( style => 'HTML::Hidden', ns => $ns );
			$gen->inject_document($doc, $sdmodel);
			my ($rh, $wh);
			pipe($rh, $wh);
			$doc->toFH($wh);
			$response->status(200);
			$response->headers->content_type('text/html');
			$content	= $rh;
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
	
	my $dsd	= blank('dataset');
	my $def	= blank('defaultGraph');
	my $si	= blank('size');
	$sdmodel->add_statement( statement( $s, $sd->url, iri($req->path) ) );
	$sdmodel->add_statement( statement( $s, $sd->defaultDatasetDescription, $dsd ) );
	$sdmodel->add_statement( statement( $dsd, $rdf->type, $sd->Dataset ) );
	if ($config->{sd}{default}) {
		$sdmodel->add_statement( statement( $dsd, $sd->defaultGraph, $def ) );
		$sdmodel->add_statement( statement( $def, $void->statItem, $si ) );
		$sdmodel->add_statement( statement( $si, $scovo->dimension, $void->numberOfTriples ) );
		$sdmodel->add_statement( statement( $si, $rdf->value, literal( $count, undef, $xsd->integer->uri_value ) ) );
	}
	if ($config->{sd}{named_graphs}) {
		my @graphs	= $model->get_contexts;
		foreach my $g (@graphs) {
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

1;

__END__

=head1 SEE ALSO

L<http://www.perlrdf.org/>

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
