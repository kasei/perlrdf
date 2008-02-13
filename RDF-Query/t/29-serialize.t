#!/usr/bin/perl
use strict;
use warnings;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;
plan qw(no_plan);	# tests => 16;

use_ok( 'RDF::Query' );

################################################################################
### AS_SPARQL TESTS
{
	my $rdql	= qq{SELECT ?person WHERE (?person foaf:name "Gregory Todd Williams") USING foaf FOR <http://xmlns.com/foaf/0.1/>};
	my $query	= new RDF::Query ( $rdql, undef, undef, 'rdql' );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> SELECT * WHERE { ?person foaf:name "Gregory Todd Williams" . }', 'rdql to sparql' );
}

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name } ORDER BY ?name";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name . } ORDER BY ?name", 'sparql to sparql' );
}

TODO: {
	local($TODO)	= 'FILTER GGP not working';
	my $sparql	= 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person ; foaf:homepage ?homepage . FILTER( REGEX( STR(?homepage), "^http://www.rpi.edu/.+") ) } ORDER BY ?p';
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person . ?p foaf:homepage ?homepage . FILTER REGEX(STR( ?homepage ), "^http://www.rpi.edu/.+") } ORDER BY ?p', 'sparql to sparql with filter' );
};

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name } ORDER BY ?name LIMIT 5 OFFSET 5";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name . } ORDER BY ?name LIMIT 5 OFFSET 5", 'sparql to sparql with slice' );
};

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
	my $sse	= $query->sse;
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
	my $sse	= $query->sse;
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
	my $sse	= $query->sse;
	is( $sse, '(join (union (join (bgp (triple _:a1 foaf:name ?name))) (join (bgp (triple _:a2 dc:title ?name)))))', 'sse: select with union' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?person
		WHERE {
			?person foaf:name ?name .
			FILTER( ?name < "Greg" )
		}
END
	my $sse		= eval { $query->sse };
	is( $sse, '(join (filter (< ?name "Greg") (join (bgp (triple ?person foaf:name ?name)))))', 'sse: select with filter <' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?person
		WHERE {
			?person foaf:name ?name .
			FILTER( REGEX(?name, "Greg") )
		}
END
	my $sse		= eval { $query->sse };
	is( $sse, '(join (filter (~~ ?name "Greg") (join (bgp (triple ?person foaf:name ?name)))))', 'sse: select with filter regex' );
}

__END__
