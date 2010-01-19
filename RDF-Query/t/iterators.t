#!/usr/bin/perl
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
	my $bridge	= $data->{'bridge'};
	
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
		ok( $query->bridge->isa_resource( $homepage ), 'binding_value_by_name' );
		is( $query->bridge->uri_value( $homepage ), 'http://kasei.us/about/foaf.xrdf#greg', 'binding_value_by_name' );
		
		my @values	= $stream->binding_values();
		is( scalar(@values), 2, 'binding_values' );
		my ($p, $h)	= @values;
		ok( $query->bridge->isa_resource( $p ), 'binding_values' );
		is( $query->bridge->uri_value( $p ), 'http://kasei.us/about/foaf.xrdf#greg', 'binding_values' );
		ok( $query->bridge->isa_resource( $h ), 'binding_values' );
		is( $query->bridge->uri_value( $h ), 'http://kasei.us/', 'binding_values' );
		
		my $count	= $stream->bindings_count;
		is( $count, 2, 'bindings_count' );
	}
	
	
	SKIP: {
		skip( "Model does not support XML sesrialization", 2 ) unless ($bridge->supports('xml'));
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
	}
	
	SKIP: {
		skip( "Model does not support JSON sesrialization", 1 ) unless ($bridge->supports('json'));
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
	
}
