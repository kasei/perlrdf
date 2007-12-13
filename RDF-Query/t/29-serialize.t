#!/usr/bin/perl
use strict;
use warnings;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;
plan tests => 10;

use_ok( 'RDF::Query' );

################################################################################
### AS_SPARQL TESTS
{
	my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT ?person
		WHERE (?person foaf:name "Gregory Todd Williams")
		USING foaf FOR <http://xmlns.com/foaf/0.1/>
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: rdql round trip: select' );
}

{
	my $rquery	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT ?person
		WHERE (?person foaf:name "Gregory Todd Williams")
		USING foaf FOR <http://xmlns.com/foaf/0.1/>
END
	my $squery	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		SELECT ?person
		WHERE { ?person foaf:name "Gregory Todd Williams" }
END
	is( $squery->as_sparql, $rquery->as_sparql, 'as_sparql: rdql-sparql equality' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		CONSTRUCT { ?p foaf:name ?name }
		WHERE  { ?p foaf:firstname ?name }
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: sparql round trip: construct' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		DESCRIBE ?p
		WHERE  { ?p foaf:name ?name }
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: sparql round trip: describe' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		ASK
		WHERE  { [ foaf:name "Gregory Todd Williams" ] }
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: sparql round trip: ask' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?name
		FROM NAMED <http://example.com/>
		WHERE  {
			GRAPH ?g {
				[ foaf:name "Gregory Todd Williams" ]
			}
		}
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: sparql round trip: select with named graph' );
}

################################################################################
### SSE TESTS

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?person
		WHERE { ?person foaf:name "Gregory Todd Williams" }
END
	my $pattern	= $query->pattern;
	my $sse		= $pattern->sse;
	is( $sse, '(join (bgp (triple ?person foaf:name "Gregory Todd Williams")))', 'sse: select' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?name
		FROM NAMED <http://example.com/>
		WHERE  {
			GRAPH ?g {
				[ foaf:name "Gregory Todd Williams" ]
			}
		}
END
	my $pattern	= $query->pattern;
	my $sse		= $pattern->sse;
	is( $sse, '(join (namedgraph ?g (join (bgp (triple _:a1 foaf:name "Gregory Todd Williams")))))', 'sse: select with named graph' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX dc: <http://purl.org/dc/elements/1.1/>
		SELECT ?name
		WHERE  {
			{ [ foaf:name ?name ] }
			UNION
			{ [ dc:title ?name ] }
		}
END
	my $pattern	= $query->pattern;
	my $sse		= $pattern->sse;
	is( $sse, '(join (union (join (bgp (triple _:a1 foaf:name ?name))) (join (bgp (triple _:a2 dc:title ?name)))))', 'sse: select with union' );
}

__END__
