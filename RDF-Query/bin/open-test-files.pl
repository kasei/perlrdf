#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{HOME}/data/prog/git/perlrdf/RDF-Trine/lib";
use lib "$ENV{HOME}/data/prog/git/perlrdf/RDF-Query/lib";

use RDF::Trine;
use RDF::Query;
use File::Spec;
use File::Slurp;
use Data::Dumper;

my $editor	= $ENV{EDITOR} || '/usr/bin/bbedit';

while (my $test = shift) {
	my $file	= $test;
	$file		=~ s/#.*$/.ttl/;
	$file		=~ s#^#xt/dawg/data-r2/#;
	my $parse	= RDF::Trine::Parser->new('turtle');
	my $store	= RDF::Trine::Store->temporary_store();
	my $model	= RDF::Trine::Model->new( $store );
	my $parser	= RDF::Trine::Parser->new('turtle');
	
	my $rdf	= read_file( $file );
	my $uri	= 'file://' . File::Spec->rel2abs( $file );
	$parser->parse_into_model ( $uri, $rdf, $model );
	
	my $sparql	= <<"END";
	PREFIX mf: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
	PREFIX qt: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#>
	PREFIX earl: <http://www.w3.org/ns/earl#>
	SELECT ?data ?query ?result WHERE {
		?test mf:name ?name ;
			mf:action [ qt:data ?data ; qt:query ?query ] ;
			mf:result ?result .
		FILTER( REGEX(STR(?test), "${test}") )
	}
END
	my $query	= RDF::Query->new( $sparql ) or warn RDF::Query->error;
	my $iter	= $query->execute( $model );
	while (my $row = $iter->next) {
		my @nodes	= map { $_->uri_value } grep { $_->isa('RDF::Trine::Node::Resource') } values %$row;
		for (@nodes) {
			substr($_, 0, index($_, "data-r2/")+8) = "xt/dawg/data-r2/";
		}
		system( $editor, @nodes );
	}

}
