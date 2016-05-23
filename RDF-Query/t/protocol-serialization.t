#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf Flower-2.rdf);
my @models	= test_models( @files );

use Test::More;

eval "use Test::JSON 0.03; use JSON 2.0;";
my $run_json_tests	= (not $@) ? 1 : 0;
my $tests_per_model	= 7 + ($run_json_tests ? 6 : 0);

plan tests => 1 + ($tests_per_model * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?homepage
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						?person foaf:homepage ?homepage .
						FILTER REGEX(STR(?homepage), "kasei")
					}
			LIMIT 1
END
		my $stream	= $query->execute( $model );
		ok( $stream->is_bindings, 'Bindings result' );
		my $xml		= $stream->as_xml;
		$xml		=~ s/^.*<sparql/<sparql/smo;	# remove xml declaration
		my $expect	= <<"END";
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="person"/>
	<variable name="homepage"/>
</head>
<results>
		<result>
			<binding name="person"><uri>http://kasei.us/about/foaf.xrdf#greg</uri></binding>
			<binding name="homepage"><uri>http://kasei.us/</uri></binding>
		</result>
</results>
</sparql>
END
		is( $xml, $expect, 'XML Bindings Results formatting' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			ASK { ?person foaf:name "Gregory Todd Williams" }
END
		my $stream	= $query->execute( $model );
		ok( $stream->is_boolean, 'Boolean result' );
		my $xml		= $stream->as_xml;
		like( $xml, qr%<boolean>true</boolean>%sm, 'XML Boolean Results formatting' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			CONSTRUCT	{ _:somebody foaf:name ?name; foaf:made ?thing }
			WHERE		{ ?thing dc:creator ?name }
END
		my $stream	= $query->execute( $model );
		ok( $stream->is_graph, 'Graph result' );
		
		my $xml		= $stream->as_xml;	# XXX remove eval when removing the TODO!
		no warnings 'uninitialized';
		like( $xml, qr%name.*?>Greg Williams<%ms, 'XML Results formatting' );
		like( $xml, qr%made\s+.*?rdf:resource="http://kasei\.us/pictures/2004/20040909-Ireland/images/DSC_5705\.jpg"%ms, 'XML Results formatting' );
	}
	
	### JSON Tests
	
	sub JSON::true;
	sub JSON::false;
	
	if ($run_json_tests) {
		{
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?person ?homepage
				WHERE	{
							?person foaf:name "Gregory Todd Williams" .
							?person foaf:homepage ?homepage .
							FILTER REGEX(STR(?homepage), "kasei")
						}
				ORDER BY ?homepage
				LIMIT 1
END
			my $stream	= $query->execute( $model );
			ok( $stream->is_bindings, 'Bindings result' );
			my $js		= $stream->as_json();
			my $expect	= {
							head	=> { vars => [qw(person homepage)] },
							results	=> {
								ordered 	=> JSON::true,
								distinct	=> JSON::false,
								bindings	=> [
									{
										person		=> { type => 'uri', value => 'http://kasei.us/about/foaf.xrdf#greg' },
										homepage	=> { type => 'uri', value => 'http://kasei.us/' },
									}
								],
							}
						};
			is_valid_json( $js, 'valid json syntax' );
			is_json( $js, to_json($expect), 'expected json results' );
		}
	
		{
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				ASK { ?person foaf:name "Gregory Todd Williams" }
END
			my $stream	= $query->execute( $model );
			ok( $stream->is_boolean, 'Boolean result' );
			my $js		= $stream->as_json;
			my $expect	= {
							head	=> { vars => [] },
							boolean	=> JSON::true,
						};
			is_valid_json( $js, 'valid json syntax' );
			is_json( $js, to_json($expect), 'expected json results' );
		}
	}
}
