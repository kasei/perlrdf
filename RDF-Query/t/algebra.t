#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Data::Dumper;
use Test::More tests => 12;
use Scalar::Util qw(reftype blessed);

use RDF::Query;

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		[
			a foaf:PersonalProfileDocument ;
			foaf:maker [
				a foaf:Person ;
				foaf:name ?name
			]
		] .
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ $pattern->referenced_variables ], ['name'], 'ppd: referenced_variables' );
	is_deeply( [ $pattern->definite_variables ], ['name'], 'ppd: definite_variables' );
	is_deeply( [ $pattern->referenced_blanks ], ['a1', 'a2'], 'ppd: referenced_blanks' );
	
}

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		?p a foaf:Person ;
			foaf:name ?name .
		OPTIONAL {
			?p foaf:homepage ?page .
		}
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ sort $pattern->referenced_variables ], [qw(name p page)], 'foaf-simple: referenced_variables' );
	is_deeply( [ sort $pattern->definite_variables ], [qw(name p)], 'foaf-simple: definite_variables' );
	is_deeply( [ sort $pattern->referenced_blanks ], [], 'foaf-simple: referenced_blanks' );
	
}

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		{
			?p a foaf:Person ;
				foaf:name ?name .
			OPTIONAL {
				?p foaf:homepage ?page .
			}
		} UNION {
			?d a foaf:Document ;
				dc:title ?name .
		}
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ sort $pattern->referenced_variables ], [qw(d name p page)], 'union: referenced_variables' );
	is_deeply( [ sort $pattern->definite_variables ], [qw(name)], 'union: definite_variables' );
	is_deeply( [ sort $pattern->referenced_blanks ], [], 'union: referenced_blanks' );
}
