#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => 1 + (37 * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:name "Gregory Todd Williams")
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		isa_ok( $query, 'RDF::Query' );
		ok( not($query->is_update), "query isn't an update" );
		
		print "# (?var qname literal)\n";
		my ($p, $c)	= $query->prepare( $model );
		my @results	= $query->execute_plan( $p, $c );
		ok( scalar(@results), 'got result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{'person'}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{'person'}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'got person uri' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:homepage <http://kasei.us/>)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		isa_ok( $query, 'RDF::Query' );
		ok( not($query->is_update), "query isn't an update" );
		
		print "# (?var qname quri)\n";
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{person}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{person}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'got person uri' );
	}
	
	{
		print "# multiple namespaces\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT
				?title
			WHERE {
				?desc rdf:type foaf:PersonalProfileDocument .
				?desc foaf:maker ?person .
				?person foaf:name "Gregory Todd Williams" .
				?desc dc:title ?title .
			}
END
		isa_ok( $query, 'RDF::Query' );
		ok( not($query->is_update), "query isn't an update" );
		
		my ($p, $c)	= $query->prepare( $model );
		my @results	= $query->execute_plan( $p, $c );
		ok( scalar(@results), 'got result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( ref($results[0]) && $results[0]{title}->isa('RDF::Trine::Node::Literal'), 'Literal' );
		is( ref($results[0]) && $results[0]{title}->literal_value, 'FOAF Description for Gregory Williams', 'got file title' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?page
			WHERE
				(?person foaf:name "Gregory Todd Williams")
				(?person foaf:homepage ?page)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		isa_ok( $query, 'RDF::Query' );
		ok( not($query->is_update), "query isn't an update" );
		
		print "# chained (name->person->homepage)\n";
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 1, 'got one field' );
		ok( $results[0]{page}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{page}->uri_value, 'http://kasei.us/', 'got homepage url' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?name ?mbox
			WHERE
				(?person foaf:homepage <http://kasei.us/>)
				(?person foaf:name ?name)
				(?person foaf:mbox ?mbox)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		isa_ok( $query, 'RDF::Query' );
		ok( not($query->is_update), "query isn't an update" );
		
		print "# chained (homepage->person->(name|mbox)\n";
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
		isa_ok( $results[0], 'HASH' );
		is( scalar(@{ [ keys %{ $results[0] } ] }), 2, 'got two field' );
		ok( $results[0]{name}->isa('RDF::Trine::Node::Literal'), 'Literal' );
		ok( $results[0]{mbox}->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $results[0]{name}->literal_value, 'Gregory Todd Williams', 'got name' );
		is( $results[0]{mbox}->uri_value, 'mailto:greg@evilfunhouse.com', 'got mbox uri' );
	}
}
