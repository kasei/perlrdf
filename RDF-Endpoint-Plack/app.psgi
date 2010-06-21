#!/usr/bin/perl

use strict;
use warnings;
use RDF::Query;
use RDF::Trine;
use Plack::Request;
use Plack::Response;
use Carp qw(confess);
use Data::Dumper;
use HTTP::Negotiate qw(choose);


sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
	
	my $response	= Plack::Response->new;
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
			my $iter	= $query->execute();
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

	return $response->finalize;
}

__END__
