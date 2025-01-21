#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my (@data)	= test_models_and_classes( @files );


use Test::More;
plan tests => 1 + 15 * scalar(@data);

use RDF::Trine::Iterator (qw(sgrep smap));

use_ok( 'RDF::Query' );
foreach my $data (@data) {
	my $model	= $data->{'modelobj'};
	
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?person ?homepage
			WHERE {
				?person a foaf:Person ;
					foaf:name "Gregory Todd Williams" ;
					foaf:homepage ?homepage .
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		
		my @names	= $stream->binding_names;
		is_deeply( \@names, [qw(person homepage)], 'binding_names' );
		is( $stream->binding_name( 1 ), 'homepage', 'bindging_name' );
		
		my $homepage	= $stream->binding_value_by_name( 'person' );
		ok( $homepage->isa('RDF::Trine::Node::Resource'), 'binding_value_by_name' );
		is( $homepage->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'binding_value_by_name' );
		
		my @values	= $stream->binding_values();
		is( scalar(@values), 2, 'binding_values' );
		my ($p, $h)	= @values;
		ok( $p->isa('RDF::Trine::Node::Resource'), 'binding_values' );
		is( $p->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'binding_values' );
		ok( $h->isa('RDF::Trine::Node::Resource'), 'binding_values' );
		is( $h->uri_value, 'http://kasei.us/', 'binding_values' );
		
		my $count	= $stream->bindings_count;
		is( $count, 2, 'bindings_count' );
	}
	
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?person
			WHERE {
				?person a foaf:Person ;
					foaf:name "Gregory Todd Williams" .
			}
END
		my $stream	= $query->execute( $model );
		my $string	= $stream->to_string;
		like( $string, qr/\A\Q<?xml version="1.0"\E.*\n\Q<sparql\E/s, 'to_string xml bindings' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			DESCRIBE ?person
			WHERE {
				?person a foaf:Person ;
					foaf:name "Gregory Todd Williams" .
			}
END
		my $stream	= $query->execute( $model );
		my $string	= $stream->as_xml;
		like( $string, qr/^\Q<rdf:RDF\E/m, 'to_string xml graph' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?person
			WHERE {
				?person a foaf:Person ;
					foaf:name "Gregory Todd Williams" .
			}
END
		my $stream	= $query->execute( $model );
		my $string	= $stream->to_string('http://www.w3.org/2001/sw/DataAccess/json-sparql/');
		like( $string, qr/\A\Q\E/m, 'to_string json' );
	}
	
}
