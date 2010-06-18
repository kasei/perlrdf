#!/usr/bin/perl

use strict;
use warnings;
use RDF::Query;
use RDF::Trine qw(statement iri blank literal);

use File::ShareDir qw(dist_dir);
use Plack::Request;
use Plack::Response;
use Carp qw(confess);
use Data::Dumper;
use Config::JFDI;
use HTTP::Negotiate qw(choose);
use RDF::Trine::Namespace qw(rdf xsd);

# warn dist_dir('RDF-Endpoint');

sub service_description {
	my $req		= shift;
	my $model	= shift;
	my $sd			= RDF::Trine::Namespace->new('http://www.w3.org/ns/sparql-service-description#');
	my $void		= RDF::Trine::Namespace->new('http://rdfs.org/ns/void#');
	my $scovo		= RDF::Trine::Namespace->new('http://purl.org/NET/scovo#');
	my $count		= $model->count_statements( undef, undef, undef, RDF::Trine::Node::Nil->new );
	my @extensions	= grep { !/kasei[.]us/ } RDF::Query->supported_extensions;
	my @functions	= grep { !/kasei[.]us/ } RDF::Query->supported_functions;

	my $sdmodel		= RDF::Trine::Model->temporary_model;
	my $s			= blank('service');
	$sdmodel->add_statement( statement( $s, $rdf->type, $sd->Service ) );
	foreach my $ext (@extensions) {
		$sdmodel->add_statement( statement( $s, $sd->languageExtension, iri($ext) ) );
	}
	foreach my $func (@functions) {
		$sdmodel->add_statement( statement( $s, $sd->extensionFunction, iri($func) ) );
	}
	
	my $dsd	= blank('dataset');
	my $def	= blank('defaultGraph');
	my $si	= blank('size');
	$sdmodel->add_statement( statement( $s, $sd->defaultDatasetDescription, $dsd ) );
	$sdmodel->add_statement( statement( $s, $sd->url, iri($req->path) ) );
	
	$sdmodel->add_statement( statement( $dsd, $rdf->type, $sd->Dataset ) );
	$sdmodel->add_statement( statement( $dsd, $sd->defaultGraph, $def ) );
	$sdmodel->add_statement( statement( $def, $void->statItem, $si ) );
	$sdmodel->add_statement( statement( $si, $scovo->dimension, $void->numberOfTriples ) );
	$sdmodel->add_statement( statement( $si, $rdf->value, literal( $count, undef, $xsd->integer->uri_value ) ) );
	return $sdmodel;
}

sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
	my $config = Config::JFDI->open( name => "RDF::Endpoint") or confess "Couldn't find config";
	
	my $store	= RDF::Trine::Store->new_with_string( $config->{store} );
	my $model	= RDF::Trine::Model->new( $store );
	
	my $response	= Plack::Response->new;
	unless ($req->path eq '/') {
		$response->status(404);
		$response->content(<<"END");
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">\n<html><head>\n<title>404 Not Found</title>\n</head><body>\n
<h1>Not Found</h1>\n<p>The requested URL was not found on this server.</p>\n</body></html>
END
		return $response->finalize;
	}
	
	my @variants;
	my %media_types	= %RDF::Trine::Serializer::media_types;
	while (my($type, $sclass) = each(%media_types)) {
		push(@variants, [$type, 1.0, $type]);
	}
	
	push(@variants, ['text/html', 1.0, 'text/html']);
	push(@variants, ['application/sparql-results+xml', 1.0, 'application/sparql-results+xml']);
	my $stype	= choose( \@variants, $req->headers );
	
	if (my $sparql = $req->param('query')) {
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', update => 1, load_data => 1 } );
		if ($query) {
			my $iter	= $query->execute( $model );
			if ($iter) {
				$response->status(200);
				if ($stype =~ /xml/) {
					$response->headers->content_type( $stype );
					$response->content( $iter->as_xml );
				} else {
					$response->headers->content_type( 'text/plain' );
					$response->content( $iter->as_string );
				}
			} else {
				$response->status(500);
			}
		} else {
			$response->status(500);
			$response->content( RDF::Query->error );
		}
	} else {
		my $sdmodel	= service_description( $req, $model );
		if (my $sclass = $RDF::Trine::Serializer::media_types{ $stype }) {
			my $s	= $sclass->new( namespaces => {
				xsd		=> $xsd->uri->uri_value,
				sd		=> 'http://www.w3.org/ns/sparql-service-description#',
				jena	=> 'java:com.hp.hpl.jena.query.function.library.',
				ldodds	=> 'java:com.ldodds.sparql.',
				kasei	=> 'http://kasei.us/2007/09/functions/',
			} );
			$response->status(200);
			$response->headers->content_type($stype);
			$response->content( $s->serialize_model_to_string($sdmodel) );
		} else {
			$response->status(200);
			$response->headers->content_type('text/html');
			$response->content(<<"END");
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>SPARQL</title></head><body>
	<form action="/" method="GET">
		<textarea id="query" name="query" rows="15" cols="80">
PREFIX foaf: &lt;http://xmlns.com/foaf/0.1/>
SELECT DISTINCT *
WHERE {
	[ a foaf:Person ; foaf:name ?name ]
}
ORDER BY ?name
</textarea><br/>
<!--
		<select id="mime-type" name="mime-type">
			<option value="">Result Format...</option>
			<option label="HTML" value="text/html">HTML</option>
			<option label="XML" value="text/xml">XML</option>
			<option label="JSON" value="application/json">JSON</option>
		</select>
-->
		<input name="submit" id="submit" type="submit" value="Submit" />
	</form>
</body></html>
END
		}
	}

	return $response->finalize;
}

__END__
