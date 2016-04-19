#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';

use utf8;
use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::Exception;
use Test::More tests => 40;

use_ok( 'RDF::Query' );

################################################################################
### AS_SPARQL TESTS

{
	my $sparql	= <<"END";
PREFIX ex: <http://example.com/>
SELECT ?x (SUM(?o) AS ?sum) WHERE {
	?x ex:price ?o
}
GROUP BY ?x
HAVING (SUM(?o) > 5)
ORDER BY ?sum
END
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX ex: <http://example.com/> SELECT ?x (SUM(?o) AS ?sum) WHERE { ?x ex:price ?o . } GROUP BY ?x HAVING (SUM(?o) > 5) ORDER BY ?sum", 'sparql to sparql aggregate' );
}

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

{
	my $sparql	= 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person ; foaf:homepage ?homepage . FILTER( REGEX( STR(?homepage), "^http://www.rpi.edu/.+") ) }';
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p WHERE { ?p a foaf:Person . ?p foaf:homepage ?homepage . FILTER( REGEX(STR(?homepage), "^http://www.rpi.edu/.+") ) . }', 'sparql to sparql with regex filter' );
};

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name . FILTER( ?name < 'Greg' ) }";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name . FILTER( (?name < "Greg") ) . }', 'sparql to sparql with less-than filter' );
}

{
	my $sparql	= "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person; foaf:name ?name } ORDER BY ?name LIMIT 5 OFFSET 5";
	my $query	= new RDF::Query ( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?person a foaf:Person . ?person foaf:name ?name . } ORDER BY ?name OFFSET 5 LIMIT 5", 'sparql to sparql with slice' );
}

{
	my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT ?person
		WHERE (?person foaf:name "Gregory Todd Williams")
		USING foaf FOR <http://xmlns.com/foaf/0.1/>
END
	my $sparql	= $query->as_sparql;
	my $query2	= RDF::Query->new( $sparql );
	my $again	= $query2->as_sparql;
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

{
	my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT *
		WHERE {
			{ ?person foaf:name ?name } UNION { ?person foaf:nick ?name }
		}
END
	my $sparql	= $query->as_sparql;
	my $query2	= RDF::Query->new( $sparql );
	my $again	= $query2->as_sparql;
	is( $sparql, $again, 'as_sparql: union' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?person
		WHERE {
			?person foaf:name ?name .
			FILTER( !BOUND(?name) )
		}
END
	my $sparql	= $query->as_sparql;
	my $again	= RDF::Query->new( $sparql )->as_sparql;
	is( $sparql, $again, 'as_sparql: select with filter !BOUND' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT ?name
		WHERE {
			?person foaf:name ?name .
		}
END
	my $sparql	= $query->as_sparql;
	my $qagain	= RDF::Query->new( $sparql );
	my $again	= $qagain->as_sparql;
	is( $sparql, $again, 'as_sparql: select DISTINCT' );
}

{
	my $sparql	= <<"END";
PREFIX bench: <http://localhost/vocabulary/benchInproc/>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT ?article
WHERE {
	?article a bench:Article .
	?article ?property ?value .
	FILTER( (?property = <http://swrc.ontoware.org/ontology#pages>) ) .
}
END
	chomp($sparql);
	$sparql		=~ s/\s+/ /gms;
	my $query	= RDF::Query->new( $sparql );
	my $string	= $query->as_sparql;
	$string		=~ s/\s+/ /gms;
	is( $string, $sparql, 'sparql to sparql with filter equality test' );
}

{
	# Github issue #132 -- Improve support of qNames in RDF::Query::Node::Resource
	{
		my $query	= RDF::Query->new('PREFIX ex: <http://example.org/> SELECT * WHERE { ?s ex:123 ?o }');
		my $sparql	= $query->as_sparql;
		like($sparql, qr/ex:123/, 'Non-alpha PrefixName');
		my $again	= RDF::Query->new( $sparql )->as_sparql;
		is( $sparql, $again, 'as_sparql: sparql round trip: Non-alpha PrefixName' );
	}

	{
		my $query	= new RDF::Query ( <<'END' );
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX 食: <http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#>
	SELECT ?name WHERE {
	  [ foaf:name ?name ;
		食:食べる 食:海老 ] . }
END
		my $sparql	= $query->as_sparql;
		like($sparql, qr/食:食べる/, 'Unicode PrefixName');
		my $again	= RDF::Query->new( $sparql )->as_sparql;
		is( $sparql, $again, 'as_sparql: sparql round trip: Unicode PrefixName' );
	}
}

{
	# Github issue #133 -- Serialization of SPARQL functions improperly uses function name prefix
	{
		my $sparql	= <<"END";
SELECT * WHERE { ?s ?p ?l . FILTER( LANGMATCHES(LANG(?l), "en") ) . }
END
		chomp($sparql);
		$sparql		=~ s/\s+/ /gms;
		my $query	= RDF::Query->new( $sparql );
		my $string	= $query->as_sparql;
		$string		=~ s/\s+/ /gms;
		is( $string, $sparql, 'sparql to sparql with LANGMATCHES filter test' );
	}
	{
		my $sparql	= <<"END";
SELECT * WHERE { ?s ?p ?l . FILTER( STRLANG(?l, "en") ) . }
END
		chomp($sparql);
		$sparql		=~ s/\s+/ /gms;
		my $query	= RDF::Query->new( $sparql );
		my $string	= $query->as_sparql;
		$string		=~ s/\s+/ /gms;
		is( $string, $sparql, 'sparql to sparql with STRLANG filter test' );
	}
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
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person) (BGP (triple ?person foaf:name "Gregory Todd Williams"))))', 'sse: select' );
# 	my $alg	= RDF::Query::Algebra->from_sse( my $string = $sse );
# 	is( _CLEAN_WS($alg->sse), _CLEAN_WS($sse), 'sse: re-serialization of expression' );
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
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?name) (namedgraph ?g (BGP (triple _:a1 foaf:name "Gregory Todd Williams")))))', 'sse: select with named graph' );
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
	is( _CLEAN_WS($sse), '(prefix ((dc: <http://purl.org/dc/elements/1.1/>) (foaf: <http://xmlns.com/foaf/0.1/>)) (project (?name) (union (BGP (triple _:a1 foaf:name ?name)) (BGP (triple _:a2 dc:title ?name)))))', 'sse: select with union' );
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
	my $sse		= $query->sse;
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person) (filter (< ?name "Greg") (BGP (triple ?person foaf:name ?name)))))', 'sse: select with filter <' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?person
		WHERE {
			?person foaf:name ?name .
			FILTER( !BOUND(?name) )
		}
END
	my $sse		= $query->sse;
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person) (filter (! (bound ?name)) (BGP (triple ?person foaf:name ?name)))))', 'sse: select with filter !BOUND' );
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
	my $sse		= $query->sse;
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person) (filter (regex ?name "Greg") (BGP (triple ?person foaf:name ?name)))))', 'sse: select with filter regex' );
}

{
	my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT *
		WHERE {
			{ ?person foaf:name ?name } UNION { ?person foaf:nick ?name }
		}
END
	my $sse		= $query->sse;
	is( _CLEAN_WS($sse), '(prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person ?name) (union (BGP (triple ?person foaf:name ?name)) (BGP (triple ?person foaf:nick ?name)))))', 'sse: select with filter regex' );
}

{
	my $query	= new RDF::Query ( <<"END" );
		BASE <http://xmlns.com/>
		PREFIX foaf: </foaf/0.1/>
		SELECT ?person
		WHERE { ?person foaf:name "Gregory Todd Williams" }
END
	my $sse	= $query->sse;
	is( _CLEAN_WS($sse), '(base <http://xmlns.com/> (prefix ((foaf: <http://xmlns.com/foaf/0.1/>)) (project (?person) (BGP (triple ?person foaf:name "Gregory Todd Williams")))))', 'sse: select' );
}

{
	my $query	= new RDF::Query ( <<"END", { update => 1 } );
		LOAD <documentURI> INTO GRAPH <uri>
END
	my $sse	= $query->sse;
	is( _CLEAN_WS($sse), '(load <documentURI> <uri>)', 'sse: load' );
}

{
	my $query	= new RDF::Query ( <<"END", { update => 1 } );
		LOAD <documentURI> ;
		SELECT * WHERE { ?s ?p ?o }
END
	my $sse	= $query->sse;
	is( _CLEAN_WS($sse), '(sequence (load <documentURI>) (project (?s ?p ?o) (BGP (triple ?s ?p ?o))))', 'sse: sequence' );
}

{
	my $sse	= '(triple _:a foaf:name "foo\\\\\\tbar\\nbaz"^^<foo://bar>)';
	my $ctx	= { namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' } };
	my $st	= RDF::Query::Algebra::Triple->from_sse( my $string = $sse, $ctx );
	is( $st->sse( $ctx ), $sse, 'sse: parse triple' );
}

{
	my $sse	= '(BGP (triple _:a foaf:name "foo\\\\\\tbar\\nbaz"^^<foo://bar>))';
	my $ctx	= { namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' } };
	my $bgp	= RDF::Query::Algebra->from_sse( my $string = $sse, $ctx );
	isa_ok( $bgp, 'RDF::Query::Algebra::BasicGraphPattern' );
	is( _CLEAN_WS($bgp->sse( $ctx )), $sse, 'sse: parse BGP' );
}

################################################################################
### VARIABLEBINDINGS TESTS
{
	my $a		= RDF::Query::Node::Literal->new('a');
	my $b		= RDF::Query::Node::Resource->new('http://b/');
	my $c		= RDF::Query::Node::Blank->new('c');
	
	{
		my $binding	= RDF::Query::VariableBindings->new({ 'a' => $a });
		is( "$binding", '{ a="a" }', 'variable binding (literal)' );
	}
	
	{
		my $binding	= RDF::Query::VariableBindings->new({ 'b' => $b });
		is( "$binding", '{ b=<http://b/> }', 'variable binding (resource)' );
	}
	
	{
		my $binding	= RDF::Query::VariableBindings->new({ 'c' => $c });
		is( "$binding", '{ c=(c) }', 'variable binding (blank)' );
	}
	
	{
		my $binding	= RDF::Query::VariableBindings->new({ 'a' => $a, b => undef, c => $c });
		is( "$binding", '{ a="a", b=(), c=(c) }', 'variable binding (literal, blank, (undef))' );
	}
}


sub _CLEAN_WS {
	my $string	= shift;
	for ($string) {
		s/\s+/ /g;
		1 while s/[)]\s+[)]/))/g;
	}
	return $string;
}
__END__
