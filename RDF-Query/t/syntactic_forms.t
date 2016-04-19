#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => 1 + (12 * scalar(@models));

use_ok( 'RDF::Query' );

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.algebra	= TRACE, Screen
# 	log4perl.appender.Screen			= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr		= 0
# 	log4perl.appender.Screen.layout		= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	
	
# 	my $s	= $model->as_stream;
# 	while ($s and not $s->end) {
# 		my $st = $s->current;
# 		warn $st->as_string;
# 	} continue { $s->next }
	
	
	# - Collections: (1 ?x 3)
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			SELECT	?x
			WHERE	{
						?a1 rdf:first "1"; rdf:rest ?a2 .
						?a2 rdf:first ?x; rdf:rest ?a3 .
						?a3 rdf:first "3"; rdf:rest rdf:nil .
					}
END
		my ($x)	= $query->get( $model );
		ok( $x, 'got collection element' );
		is( $x->literal_value, 2 );
	}

	# - Collections: (1 ?x 3)
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			SELECT	?x
			WHERE	{
						("1" ?x "3")
					}
END
		my ($x)	= $query->get( $model );
		ok( $x, 'got collection triples' );
		is( $x->literal_value, 2 );
	}

	# - Collections: ?s ?p (1 ?x 3)
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX test: <http://kasei.us/e/ns/test#>
			SELECT	?x
			WHERE	{
						<http://kasei.us/about/foaf.xrdf#greg> test:mycollection ("1" ?x "3") .
					}
END
		my ($x)	= $query->get( $model );
		ok( $x, 'got object collection triples' );
		is( $x->literal_value, 2 );
	}

	# - Object Lists: ?x foaf:nick "kasei", "kasei_" .
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						?x foaf:nick "kasei", "The Samo Fool" .
						?x foaf:name ?name
					}
END
		my ($name)	= $query->get( $model );
		ok( $name, 'got name' );
		is( $name->literal_value, 'Gregory Todd Williams', 'Gregory Todd Williams' );
	}

	# - Blank Nodes: [ :p "v" ] and [] :p "v" .
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; geo:lat "52.972770"; foaf:name ?name ]
					}
END
		my ($name)	= $query->get( $model );
		ok( $name, 'got name' );
		is( $name->literal_value, 'Cliffs of Moher, Ireland', 'Cliffs of Moher, Ireland' );
	}

	# - 'a': ?x a :Class . [ a :myClass ] :p "v" .
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; geo:lat "52.972770"; foaf:name ?name ]
					}
END
		my ($name)	= $query->get( $model );
		ok( $name, 'got name' );
		is( $name->literal_value, 'Cliffs of Moher, Ireland', 'Cliffs of Moher, Ireland' );
	}
}
