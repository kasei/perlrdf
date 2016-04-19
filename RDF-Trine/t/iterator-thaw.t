#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 10;

use Data::Dumper;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;

my $BASE_PORT	= 9015;

{
	my $string	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="p"/>
	<variable name="name"/>
</head>
<results>
		<result>
			<binding name="p"><bnode>r1196945277r60184r136</bnode></binding>
			<binding name="name"><literal datatype="http://www.w3.org/2000/01/rdf-schema#Literal">Adam</literal></binding>
		</result>
		<result>
			<binding name="p"><uri>http://kasei.us/about/foaf.xrdf#greg</uri></binding>
			<binding name="name"><literal xml:lang="en">Greg</literal></binding>
		</result>
</results>
</sparql>
END
	my $stream	= RDF::Trine::Iterator->from_string( $string )->materialize;
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	ok( $stream->is_bindings, 'is_bindings' );
	my @values	= $stream->get_all;
	is( scalar(@values), 2, 'expected result count' );
	
	{
		my $data	= $stream->next;
		my $lit		= $data->{name};
		is( $lit->literal_value, 'Adam', 'name 1' );
		is( $lit->literal_datatype, 'http://www.w3.org/2000/01/rdf-schema#Literal', 'datatype' );
	}

	{
		my $data	= $stream->next;
		my $lit		= $data->{name};
		is( $lit->literal_value, 'Greg', 'name 2' );
		is( $lit->literal_value_language, 'en', 'language' );
	}
}

{
	my $string	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head></head>
<results>
	<boolean>true</boolean>
</results>
</sparql>
END
	my $stream	= RDF::Trine::Iterator->from_string( $string );
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	ok( $stream->is_boolean, 'is_boolean' );
	ok( $stream->get_boolean, 'expected result boolean' );
}


