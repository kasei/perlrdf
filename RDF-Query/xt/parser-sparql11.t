#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 114;
use YAML;
use Data::Dumper;
use Scalar::Util qw(reftype);
use RDF::Query;

use_ok( 'RDF::Query::Parser::SPARQL11' );

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.parser          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $parser	= RDF::Query::Parser::SPARQL11->new();
isa_ok( $parser, 'RDF::Query::Parser::SPARQL11' );


my (@data)	= YAML::Load(do { local($/) = undef; <DATA> });
foreach (@data) {
	next unless (reftype($_) eq 'ARRAY');
	my ($name, $sparql, $correct)	= @$_;
	my $parsed	= $parser->parse( $sparql, undef, 1 );
	my $r	= is_deeply( $parsed, $correct, $name );
	unless ($r) {
		warn 'PARSE ERROR: ' . $parser->error;
# 		my $triples	= $parsed->{triples} || [];
# 		foreach my $t (@$triples) {
# 			warn $t->as_sparql . "\n";
# 		}
		
#		warn Dumper($parsed);
		my $dump	= YAML::Dump($parsed);
		$dump		=~ s/\n/\n  /g;
		warn $dump;
		exit;
	}
}


# sub _____ERRORS______ {}
# ##### ERRORS
# 
# {
# 	my $sparql	= <<"END";
# 		PREFIX : <http://example.org/>
# 		SELECT *
# 		WHERE
# 		{
# 			_:a ?p ?v . { _:a ?q 1 }
# 		}
# END
# 	my $parsed	= $parser->parse( $sparql );
# 	is( $parsed, undef, '(DAWG) syn-bad-34.rq' );
# 	if ($parsed) {
# 		warn "unexpected parse tree: " . Dumper($parsed);
# 	}
# 	like( $parser->error, qr/^Same blank node identifier/, 'got expected syntax error' );	# XXX
# }


__END__
---
- Subselect
- |
  PREFIX : <http://people.example/>
  SELECT ?y ?name WHERE {
    :alice :knows ?y .
    {
      SELECT ?y ?name WHERE {
        ?y :name ?name
      }
      ORDER BY ?name
      LIMIT 1
    }
  }
- method: SELECT
  namespaces: &1
    __DEFAULT__: http://people.example/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://people.example/alice
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://people.example/knows
            - !!perl/array:RDF::Query::Node::Variable
              - y
        - !!perl/array:RDF::Query::Algebra::SubSelect
          - !!perl/hash:RDF::Query
            base: ~
            parsed:
              method: SELECT
              triples:
                - !!perl/array:RDF::Query::Algebra::Limit
                  - !!perl/array:RDF::Query::Algebra::Project
                    - !!perl/array:RDF::Query::Algebra::Sort
                      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                          - !!perl/array:RDF::Query::Algebra::Triple
                            - !!perl/array:RDF::Query::Node::Variable
                              - y
                            - !!perl/array:RDF::Query::Node::Resource
                              - URI
                              - http://people.example/name
                            - !!perl/array:RDF::Query::Node::Variable
                              - name
                      -
                        - ASC
                        - !!perl/array:RDF::Query::Node::Variable
                          - name
                    -
                      - &1 !!perl/array:RDF::Query::Node::Variable
                        - y
                      - &2 !!perl/array:RDF::Query::Node::Variable
                        - name
                  - 1
              variables:
                - *1
                - *2
      -
        - &3 !!perl/array:RDF::Query::Node::Variable
          - y
        - &4 !!perl/array:RDF::Query::Node::Variable
          - name
  variables:
    - *3
    - *4
---
- Subselect with differing projection
- |
  PREFIX : <http://people.example/>
  SELECT ?name WHERE {
    :alice :knows ?y .
    {
      SELECT ?y ?name WHERE {
        ?y :name ?name
      }
      ORDER BY ?name
      LIMIT 1
    }
  }
- method: SELECT
  namespaces: &1
    __DEFAULT__: http://people.example/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://people.example/alice
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://people.example/knows
            - !!perl/array:RDF::Query::Node::Variable
              - y
        - !!perl/array:RDF::Query::Algebra::SubSelect
          - !!perl/hash:RDF::Query
            base: ~
            parsed:
              method: SELECT
              triples:
                - !!perl/array:RDF::Query::Algebra::Limit
                  - !!perl/array:RDF::Query::Algebra::Project
                    - !!perl/array:RDF::Query::Algebra::Sort
                      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                          - !!perl/array:RDF::Query::Algebra::Triple
                            - !!perl/array:RDF::Query::Node::Variable
                              - y
                            - !!perl/array:RDF::Query::Node::Resource
                              - URI
                              - http://people.example/name
                            - !!perl/array:RDF::Query::Node::Variable
                              - name
                      -
                        - ASC
                        - !!perl/array:RDF::Query::Node::Variable
                          - name
                    -
                      - &1 !!perl/array:RDF::Query::Node::Variable
                        - y
                      - &2 !!perl/array:RDF::Query::Node::Variable
                        - name
                  - 1
              variables:
                - *1
                - *2
      -
        - &3 !!perl/array:RDF::Query::Node::Variable
          - name
  variables:
    - *3
---
- EXISTS filter
- |
  SELECT *
  WHERE {
    {}
    FILTER(EXISTS { ?s a <type> })
  }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:exists
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - s
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - type
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
      - &1 []
  variables: *1
---
- NOT EXISTS filter
- |
  SELECT *
  WHERE {
    ?s a <type>
    FILTER(NOT EXISTS { ?s a <type2> })
  }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Unary
          - '!'
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - sparql:exists
            - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
              - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                - !!perl/array:RDF::Query::Algebra::Triple
                  - !!perl/array:RDF::Query::Node::Variable
                    - s
                  - !!perl/array:RDF::Query::Node::Resource
                    - URI
                    - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                  - !!perl/array:RDF::Query::Node::Resource
                    - URI
                    - type2
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - s
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - type
      -
        - &1 !!perl/array:RDF::Query::Node::Variable
          - s
  variables:
    - *1
---
- SELECT expression
- |
  PREFIX  dc:  <http://purl.org/dc/elements/1.1/>
  PREFIX  ns:  <http://example.org/ns#>
  SELECT  ?title (?p*(1-?discount) AS ?price)
     { ?x ns:price ?p .
       ?x dc:title ?title . 
       ?x ns:discount ?discount 
     }
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
    ns: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Extend
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/ns#price
              - !!perl/array:RDF::Query::Node::Variable
                - p
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://purl.org/dc/elements/1.1/title
              - !!perl/array:RDF::Query::Node::Variable
                - title
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/ns#discount
              - !!perl/array:RDF::Query::Node::Variable
                - discount
        -
          - &1 !!perl/array:RDF::Query::Expression::Alias
            - alias
            - &2 !!perl/array:RDF::Query::Node::Variable
              - price
            - !!perl/array:RDF::Query::Expression::Binary
              - '*'
              - !!perl/array:RDF::Query::Node::Variable
                - p
              - !!perl/array:RDF::Query::Expression::Binary
                - -
                - !!perl/array:RDF::Query::Node::Literal
                  - 1
                  - ~
                  - http://www.w3.org/2001/XMLSchema#integer
                - !!perl/array:RDF::Query::Node::Variable
                  - discount
      -
        - &3 !!perl/array:RDF::Query::Node::Variable
          - title
        - *2
  variables:
    - *3
    - *1
---
- GROUP_CONCAT Aggregate
- |
  PREFIX  dc:  <http://purl.org/dc/elements/1.1/>
  PREFIX  ns:  <http://example.org/ns#>
  SELECT (GROUP_CONCAT(?title) AS ?titles)
     { ?x dc:title ?title . 
       ?x ns:discount ?discount 
     }
  GROUP BY ?discount
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
    ns: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Extend
        - !!perl/array:RDF::Query::Algebra::Aggregate
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.1/title
                - !!perl/array:RDF::Query::Node::Variable
                  - title
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#discount
                - !!perl/array:RDF::Query::Node::Variable
                  - discount
          -
            - !!perl/array:RDF::Query::Node::Variable
              - discount
          -
            - GROUP_CONCAT(?title)
            -
              - GROUP_CONCAT
              - {}
              - !!perl/array:RDF::Query::Node::Variable
                - title
        -
          - &1 !!perl/array:RDF::Query::Expression::Alias
            - alias
            - &2 !!perl/array:RDF::Query::Node::Variable
              - titles
            - !!perl/array:RDF::Query::Node::Variable::ExpressionProxy
              - GROUP_CONCAT(?title)
      -
        - *2
  variables:
    - *1
---
- Aggregate with HAVING Clause
- |
  PREFIX : <http://books.example/>
  SELECT (SUM(?lprice) AS ?totalPrice)
  WHERE {
    ?org :affiliates ?auth .
    ?auth :writesBook ?book .
    ?book :price ?lprice .
  }
  GROUP BY ?org
  HAVING (SUM(?lprice) > 10)
- method: SELECT
  namespaces:
    __DEFAULT__: http://books.example/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - '>'
          - !!perl/array:RDF::Query::Node::Variable::ExpressionProxy
            - SUM(?lprice)
          - !!perl/array:RDF::Query::Node::Literal
            - 10
            - ~
            - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::Extend
            - !!perl/array:RDF::Query::Algebra::Aggregate
              - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - !!perl/array:RDF::Query::Node::Variable
                      - org
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://books.example/affiliates
                    - !!perl/array:RDF::Query::Node::Variable
                      - auth
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - !!perl/array:RDF::Query::Node::Variable
                      - auth
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://books.example/writesBook
                    - !!perl/array:RDF::Query::Node::Variable
                      - book
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - !!perl/array:RDF::Query::Node::Variable
                      - book
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://books.example/price
                    - !!perl/array:RDF::Query::Node::Variable
                      - lprice
              -
                - !!perl/array:RDF::Query::Node::Variable
                  - org
              -
                - SUM(?lprice)
                -
                  - SUM
                  - {}
                  - !!perl/array:RDF::Query::Node::Variable
                    - lprice
            -
              - &1 !!perl/array:RDF::Query::Expression::Alias
                - alias
                - &2 !!perl/array:RDF::Query::Node::Variable
                  - totalPrice
                - !!perl/array:RDF::Query::Node::Variable::ExpressionProxy
                  - SUM(?lprice)
      -
        - *2
  variables:
    - *1
---
- single triple; no prefix
- |
  SELECT ?node
  WHERE {
    ?node a <http://kasei.us/e/ns/mt/blog> .
  }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - node
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/e/ns/mt/blog
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - node
  variables: *1
---
- simple DESCRIBE
- |
  DESCRIBE ?node
  WHERE { ?node a <http://kasei.us/e/ns/mt/blog> }
- method: DESCRIBE
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
      - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - node
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://kasei.us/e/ns/mt/blog
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - node
---
- SELECT, WHERE
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?page
  WHERE	{
  			?person foaf:name "Gregory Todd Williams" .
  			?person foaf:homepage ?page .
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/homepage
            - !!perl/array:RDF::Query::Node::Variable
              - page
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - page
  variables: *1
---
- SELECT, WHERE; variables with "$"
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	$page
  WHERE	{
  			$person foaf:name "Gregory Todd Williams" .
  			$person foaf:homepage $page .
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/homepage
            - !!perl/array:RDF::Query::Node::Variable
              - page
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - page
  variables: *1
---
- VarUri EQ OR constraint, numeric comparison constraint
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?image ?point ?lat
  WHERE	{
  			?point geo:lat ?lat .
  			?image ?pred ?point .
  			FILTER(
  				(?pred = <http://purl.org/dc/terms/spatial> || ?pred = <http://xmlns.com/foaf/0.1/based_near>)
  				&&		?lat > 52.988674
  				&&		?lat < 53.036526
  			) .
  }
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:logical-and
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - sparql:logical-or
            - !!perl/array:RDF::Query::Expression::Binary
              - ==
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://purl.org/dc/terms/spatial
            - !!perl/array:RDF::Query::Expression::Binary
              - ==
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/based_near
          - !!perl/array:RDF::Query::Expression::Binary
            - '>'
            - !!perl/array:RDF::Query::Node::Variable
              - lat
            - !!perl/array:RDF::Query::Node::Literal
              - 52.988674
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
          - !!perl/array:RDF::Query::Expression::Binary
            - <
            - !!perl/array:RDF::Query::Node::Variable
              - lat
            - !!perl/array:RDF::Query::Node::Literal
              - 53.036526
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- regex constraint; no trailing '.'
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name "Gregory Todd Williams" .
  			?person foaf:homepage ?homepage .
  			FILTER	REGEX(?homepage, "kasei")
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:regex
          - !!perl/array:RDF::Query::Node::Variable
            - homepage
          - !!perl/array:RDF::Query::Node::Literal
            - kasei
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Literal
                - Gregory Todd Williams
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/homepage
              - !!perl/array:RDF::Query::Node::Variable
                - homepage
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with variable/function-call equality
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  PREFIX    func: <http://example.com/>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name "Gregory Todd Williams" .
  			?person ?pred ?homepage .
  			FILTER( ?pred = func:homepagepred() ) .
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
    func: http://example.com/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Node::Variable
            - pred
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.com/homepagepred
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Literal
                - Gregory Todd Williams
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - homepage
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with variable/function-call equality
- |
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		SELECT	?person ?homepage
  		WHERE	{
  					?person foaf:name "Gregory Todd Williams" .
  					?person ?pred ?homepage .
  					FILTER( ?pred = <func:homepagepred>() ) .
  				}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Node::Variable
            - pred
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - func:homepagepred
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Literal
                - Gregory Todd Williams
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - homepage
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with LANG(?var)/literal equality
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name ?name .
  			FILTER( LANG(?name) = 'en' ) .
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - sparql:lang
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Node::Literal
            - en
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with LANGMATCHES(?var, 'literal')
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name ?name .
  			FILTER( LANGMATCHES(?name, "foo"@en ) ).
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:langmatches
          - !!perl/array:RDF::Query::Node::Variable
            - name
          - !!perl/array:RDF::Query::Node::Literal
            - foo
            - en
            - ~
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with isLITERAL(?var)
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name ?name .
  			FILTER( isLITERAL(?name) ).
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:isliteral
          - !!perl/array:RDF::Query::Node::Variable
            - name
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- filter with DATATYPE(?var)/URI equality
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name ?name .
  			FILTER( DATATYPE(?name) = rdf:Literal ) .
  		}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - sparql:datatype
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#Literal
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *1
---
- multiple attributes using ';'
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?person ?homepage
  WHERE	{
  			?person foaf:name "Gregory Todd Williams" ; foaf:homepage ?homepage .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/homepage
            - !!perl/array:RDF::Query::Node::Variable
              - homepage
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *2
---
- predicate with full qURI
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?person
  WHERE	{
  			?person foaf:name "Gregory Todd Williams", "Greg Williams" .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - person
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - Greg Williams
      - &3
        - !!perl/array:RDF::Query::Node::Variable
          - person
  variables: *3
---
- "'a' rdf:type"
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?person
  WHERE	{
  			?person <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> foaf:Person
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Person
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
  variables: *1
---
- "'a' rdf:type; multiple attributes using ';'"
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			?person a foaf:Person ; foaf:name ?name .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Person
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- "blank node subject; multiple attributes using ';'"
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?nick
  WHERE	{
  			[ foaf:name "Gregory Todd Williams" ; foaf:nick ?nick ] .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/nick
            - !!perl/array:RDF::Query::Node::Variable
              - nick
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - nick
  variables: *2
---
- "blank node subject; using brackets '[...]'; 'a' rdf:type"
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			[ a foaf:Person ] foaf:name ?name .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Person
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- "blank node subject; empty brackets '[]'"
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			[] foaf:name ?name .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *1
---
- blank node object
- |
  PREFIX dao: <http://kasei.us/ns/dao#>
  PREFIX dc: <http://purl.org/dc/elements/1.1/>
  PREFIX beer: <http://www.csd.abdn.ac.uk/research/AgentCities/ontologies/beer#>
  
  SELECT ?name
  WHERE {
  	?me dao:consumed [ a beer:Ale ; beer:name ?name ] .
  }
- method: SELECT
  namespaces:
    beer: http://www.csd.abdn.ac.uk/research/AgentCities/ontologies/beer#
    dao: http://kasei.us/ns/dao#
    dc: http://purl.org/dc/elements/1.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.csd.abdn.ac.uk/research/AgentCities/ontologies/beer#Ale
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.csd.abdn.ac.uk/research/AgentCities/ontologies/beer#name
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - me
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/ns/dao#consumed
            - *1
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- blank node; using qName _:abc
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			_:abc foaf:name ?name .
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - abc
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *1
---
- select with ORDER BY
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			?person a foaf:Person; foaf:name ?name
  		}
  ORDER BY ?name
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
        -
          - ASC
          - !!perl/array:RDF::Query::Node::Variable
            - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- select with DISTINCT
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	DISTINCT ?name
  WHERE	{
  			?person a foaf:Person; foaf:name ?name
  		}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Distinct
      - !!perl/array:RDF::Query::Algebra::Project
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
        - &2
          - !!perl/array:RDF::Query::Node::Variable
            - name
  variables: *2
---
- select with ORDER BY; asc()
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  			?person a foaf:Person; foaf:name ?name
  		}
  ORDER BY asc( ?name )
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
        -
          - ASC
          - !!perl/array:RDF::Query::Node::Variable
            - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- select with ORDER BY; DESC()
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?name
  		WHERE	{
  					?person a foaf:Person; foaf:name ?name
  				}
  		ORDER BY DESC(?name)
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
        -
          - DESC
          - !!perl/array:RDF::Query::Node::Variable
            - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- select with ORDER BY; DESC(); with LIMIT
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?name
  		WHERE	{
  					?person a foaf:Person; foaf:name ?name
  				}
  		ORDER BY DESC(?name) LIMIT 10
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Limit
      - !!perl/array:RDF::Query::Algebra::Project
        - !!perl/array:RDF::Query::Algebra::Sort
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - &1 !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/Person
              - !!perl/array:RDF::Query::Algebra::Triple
                - *1
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
          -
            - DESC
            - !!perl/array:RDF::Query::Node::Variable
              - name
        - &2
          - !!perl/array:RDF::Query::Node::Variable
            - name
      - 10
  variables: *2
---
- select with ORDER BY; DESC(); with LIMIT
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?name
  		WHERE	{
  					?person a foaf:Person; foaf:name ?name
  				}
  		ORDER BY DESC(?name) LIMIT 10 OFFSET 10
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Limit
      - !!perl/array:RDF::Query::Algebra::Offset
        - !!perl/array:RDF::Query::Algebra::Project
          - !!perl/array:RDF::Query::Algebra::Sort
            - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
              - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                - !!perl/array:RDF::Query::Algebra::Triple
                  - &1 !!perl/array:RDF::Query::Node::Variable
                    - person
                  - !!perl/array:RDF::Query::Node::Resource
                    - URI
                    - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                  - !!perl/array:RDF::Query::Node::Resource
                    - URI
                    - http://xmlns.com/foaf/0.1/Person
                - !!perl/array:RDF::Query::Algebra::Triple
                  - *1
                  - !!perl/array:RDF::Query::Node::Resource
                    - URI
                    - http://xmlns.com/foaf/0.1/name
                  - !!perl/array:RDF::Query::Node::Variable
                    - name
            -
              - DESC
              - !!perl/array:RDF::Query::Node::Variable
                - name
          - &2
            - !!perl/array:RDF::Query::Node::Variable
              - name
        - 10
      - 10
  variables: *2
---
- select with ORDER BY; DESC(); with LIMIT; variables with "$"
- |2
  		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX dc: <http://purl.org/dc/elements/1.1/>
  		 select $pic $thumb $date 
  		 WHERE { $pic foaf:thumbnail $thumb .
  		 $pic dc:date $date } order by desc($date) limit 10
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Limit
      - !!perl/array:RDF::Query::Algebra::Project
        - !!perl/array:RDF::Query::Algebra::Sort
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - pic
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/thumbnail
                - !!perl/array:RDF::Query::Node::Variable
                  - thumb
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - pic
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.1/date
                - !!perl/array:RDF::Query::Node::Variable
                  - date
          -
            - DESC
            - !!perl/array:RDF::Query::Node::Variable
              - date
        - &1
          - !!perl/array:RDF::Query::Node::Variable
            - pic
          - !!perl/array:RDF::Query::Node::Variable
            - thumb
          - !!perl/array:RDF::Query::Node::Variable
            - date
      - 10
  variables: *1
---
- FILTER function call 1
- |2
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
  		SELECT	?image ?point ?lat
  		WHERE	{
  					?point geo:lat ?lat .
  					?image ?pred ?point .
  					FILTER( mygeo:distance(?point, +41.849331, -71.392) < 10 )
  				}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    mygeo: http://kasei.us/e/ns/geo#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - <
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/e/ns/geo#distance
            - !!perl/array:RDF::Query::Node::Variable
              - point
            - !!perl/array:RDF::Query::Node::Literal
              - +41.849331
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
            - !!perl/array:RDF::Query::Node::Literal
              - -71.392
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
          - !!perl/array:RDF::Query::Node::Literal
            - 10
            - ~
            - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- OLDFILTER function call 2
- |2
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
  		SELECT	?image ?point ?lat
  		WHERE	{
  					?point geo:lat ?lat .
  					?image ?pred ?point .
  					FILTER( mygeo:distance(?point, 41.849331, -71.392) < 5 + 5 )
  				}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    mygeo: http://kasei.us/e/ns/geo#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - <
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/e/ns/geo#distance
            - !!perl/array:RDF::Query::Node::Variable
              - point
            - !!perl/array:RDF::Query::Node::Literal
              - 41.849331
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
            - !!perl/array:RDF::Query::Node::Literal
              - -71.392
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
          - !!perl/array:RDF::Query::Expression::Binary
            - +
            - !!perl/array:RDF::Query::Node::Literal
              - 5
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
            - !!perl/array:RDF::Query::Node::Literal
              - 5
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- OLDFILTER function call 3
- |2
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
  		SELECT	?image ?point ?lat
  		WHERE	{
  					?point geo:lat ?lat .
  					?image ?pred ?point .
  					FILTER( mygeo:distance(?point, 41.849331, -71.392) < 5 * 5 )
  				}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    mygeo: http://kasei.us/e/ns/geo#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - <
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/e/ns/geo#distance
            - !!perl/array:RDF::Query::Node::Variable
              - point
            - !!perl/array:RDF::Query::Node::Literal
              - 41.849331
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
            - !!perl/array:RDF::Query::Node::Literal
              - -71.392
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
          - !!perl/array:RDF::Query::Expression::Binary
            - '*'
            - !!perl/array:RDF::Query::Node::Literal
              - 5
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
            - !!perl/array:RDF::Query::Node::Literal
              - 5
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- multiple FILTERs; with function call
- |2
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
  		SELECT	?image ?point ?name
  		WHERE	{
  					?image dcterms:spatial ?point .
  					?point foaf:name ?name .
  					FILTER( mygeo:distance(?point, 41.849331, -71.392) < 10 ) .
  					FILTER REGEX(?name, "Providence, RI")
  				}
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    mygeo: http://kasei.us/e/ns/geo#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:regex
          - !!perl/array:RDF::Query::Node::Variable
            - name
          - !!perl/array:RDF::Query::Node::Literal
            - 'Providence, RI'
        - !!perl/array:RDF::Query::Algebra::Filter
          - FILTER
          - !!perl/array:RDF::Query::Expression::Binary
            - <
            - !!perl/array:RDF::Query::Expression::Function
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://kasei.us/e/ns/geo#distance
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Literal
                - 41.849331
                - ~
                - http://www.w3.org/2001/XMLSchema#decimal
              - !!perl/array:RDF::Query::Node::Literal
                - -71.392
                - ~
                - http://www.w3.org/2001/XMLSchema#decimal
            - !!perl/array:RDF::Query::Node::Literal
              - 10
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - image
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/terms/spatial
                - !!perl/array:RDF::Query::Node::Variable
                  - point
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - point
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *1
---
- "optional triple '{...}'"
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?person ?name ?mbox
  		WHERE	{
  					?person foaf:name ?name .
  					OPTIONAL { ?person foaf:mbox ?mbox }
  				}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/mbox
                - !!perl/array:RDF::Query::Node::Variable
                  - mbox
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - name
        - !!perl/array:RDF::Query::Node::Variable
          - mbox
  variables: *1
---
- "optional triples '{...; ...}'"
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?person ?name ?mbox ?nick
  		WHERE	{
  					?person foaf:name ?name .
  					OPTIONAL {
  						?person foaf:mbox ?mbox; foaf:nick ?nick
  					}
  				}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - &1 !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/mbox
                - !!perl/array:RDF::Query::Node::Variable
                  - mbox
              - !!perl/array:RDF::Query::Algebra::Triple
                - *1
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/nick
                - !!perl/array:RDF::Query::Node::Variable
                  - nick
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - name
        - !!perl/array:RDF::Query::Node::Variable
          - mbox
        - !!perl/array:RDF::Query::Node::Variable
          - nick
  variables: *2
---
- union; sparql 6.2
- |2
  		PREFIX dc10:  <http://purl.org/dc/elements/1.1/>
  		PREFIX dc11:  <http://purl.org/dc/elements/1.0/>
  		SELECT	?title ?author
  		WHERE	{
  					{ ?book dc10:title ?title .  ?book dc10:creator ?author }
  					UNION
  					{ ?book dc11:title ?title .  ?book dc11:creator ?author }
  				}
- method: SELECT
  namespaces:
    dc10: http://purl.org/dc/elements/1.1/
    dc11: http://purl.org/dc/elements/1.0/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Union
          - UNION
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - book
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.1/title
                - !!perl/array:RDF::Query::Node::Variable
                  - title
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - book
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.1/creator
                - !!perl/array:RDF::Query::Node::Variable
                  - author
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - book
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.0/title
                - !!perl/array:RDF::Query::Node::Variable
                  - title
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - book
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.0/creator
                - !!perl/array:RDF::Query::Node::Variable
                  - author
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - title
        - !!perl/array:RDF::Query::Node::Variable
          - author
  variables: *1
---
- literal language tag @en
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?person ?homepage
  		WHERE	{
  					?person foaf:name "Gary P"@en ; foaf:homepage ?homepage .
  				}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gary P
              - en
              - ~
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/homepage
            - !!perl/array:RDF::Query::Node::Variable
              - homepage
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - homepage
  variables: *2
---
- typed literal ^^URI
- |2
  		PREFIX	dc: <http://purl.org/dc/elements/1.1/>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?image
  		WHERE	{
  					?image dc:date "2005-04-07T18:27:56-04:00"^^<http://www.w3.org/2001/XMLSchema#dateTime>
  				}
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - image
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/date
            - !!perl/array:RDF::Query::Node::Literal
              - 2005-04-07T18:27:56-04:00
              - ~
              - http://www.w3.org/2001/XMLSchema#dateTime
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
  variables: *1
---
- typed literal ^^qName
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dc: <http://purl.org/dc/elements/1.1/>
  		PREFIX  xs: <http://www.w3.org/2001/XMLSchema#>
  		SELECT	?image
  		WHERE	{
  					?image dc:date "2005-04-07T18:27:56-04:00"^^xs:dateTime
  				}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    dc: http://purl.org/dc/elements/1.1/
    xs: http://www.w3.org/2001/XMLSchema#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - image
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/date
            - !!perl/array:RDF::Query::Node::Literal
              - 2005-04-07T18:27:56-04:00
              - ~
              - http://www.w3.org/2001/XMLSchema#dateTime
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
  variables: *1
---
- subject collection syntax
- |2
  		SELECT	?x
  		WHERE	{ (1 ?x 3) }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Variable
              - x
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - &5 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a3
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 3
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
      - &6
        - !!perl/array:RDF::Query::Node::Variable
          - x
  variables: *6
---
- subject collection syntax; with pred-obj.
- |2
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		SELECT	?x
  		WHERE	{ (1 ?x 3) foaf:name "My Collection" }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Variable
              - x
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - &5 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a3
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 3
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - My Collection
      - &6
        - !!perl/array:RDF::Query::Node::Variable
          - x
  variables: *6
---
- subject collection syntax; object collection syntax
- |2
  		PREFIX dc: <http://purl.org/dc/elements/1.1/>
  		SELECT	?x
  		WHERE	{ (1 ?x 3) dc:subject (1 2 3) }
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Variable
              - x
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - &5 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a3
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 3
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - &6 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a5
            - &7 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *6
            - &8 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &9 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a6
          - !!perl/array:RDF::Query::Algebra::Triple
            - *9
            - *7
            - !!perl/array:RDF::Query::Node::Literal
              - 2
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *9
            - *8
            - &10 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a7
          - !!perl/array:RDF::Query::Algebra::Triple
            - *10
            - *7
            - !!perl/array:RDF::Query::Node::Literal
              - 3
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *10
            - *8
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/subject
            - *6
      - &11
        - !!perl/array:RDF::Query::Node::Variable
          - x
  variables: *11
---
- object collection syntax
- |2
  		PREFIX test: <http://kasei.us/e/ns/test#>
  		SELECT	?x
  		WHERE	{
  					<http://kasei.us/about/foaf.xrdf#greg> test:mycollection (1 ?x 3) .
  				}
- method: SELECT
  namespaces:
    test: http://kasei.us/e/ns/test#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Variable
              - x
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - &5 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a3
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 3
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *5
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/about/foaf.xrdf#greg
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://kasei.us/e/ns/test#mycollection
            - *1
      - &6
        - !!perl/array:RDF::Query::Node::Variable
          - x
  variables: *6
---
- SELECT *
- |2
  		SELECT *
  		WHERE { ?a ?a ?b . }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - a
            - !!perl/array:RDF::Query::Node::Variable
              - a
            - !!perl/array:RDF::Query::Node::Variable
              - b
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - a
        - !!perl/array:RDF::Query::Node::Variable
          - b
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - a
    - !!perl/array:RDF::Query::Node::Variable
      - b
---
- default prefix
- |2
  		PREFIX	: <http://xmlns.com/foaf/0.1/>
  		SELECT	?person
  		WHERE	{
  					?person :name "Gregory Todd Williams", "Greg Williams" .
  				}
- method: SELECT
  namespaces:
    __DEFAULT__: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - person
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Literal
              - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - Greg Williams
      - &3
        - !!perl/array:RDF::Query::Node::Variable
          - person
  variables: *3
---
- select from named; single triple; no prefix
- |2
  			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  			SELECT ?src ?name
  			FROM NAMED <file://data/named_graphs/alice.rdf>
  			FROM NAMED <file://data/named_graphs/bob.rdf>
  			WHERE {
  				GRAPH ?src { ?x foaf:name ?name }
  			}
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources:
    -
      - !!perl/array:RDF::Query::Node::Resource
        - URI
        - file://data/named_graphs/alice.rdf
      - NAMED
    -
      - !!perl/array:RDF::Query::Node::Resource
        - URI
        - file://data/named_graphs/bob.rdf
      - NAMED
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::NamedGraph
          - GRAPH
          - &1 !!perl/array:RDF::Query::Node::Variable
            - src
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - src
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- ASK FILTER; using <= (shouldn't parse as '<')
- |2
  				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
  				ASK {
  					FILTER ( "1995-11-05"^^xsd:dateTime <= "1994-11-05T13:15:30Z"^^xsd:dateTime ) .
  				}
- method: ASK
  namespaces:
    xsd: http://www.w3.org/2001/XMLSchema#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Filter
      - FILTER
      - !!perl/array:RDF::Query::Expression
        - <=
        - !!perl/array:RDF::Query::Node::Literal
          - 1995-11-05
          - ~
          - http://www.w3.org/2001/XMLSchema#dateTime
        - !!perl/array:RDF::Query::Node::Literal
          - 1994-11-05T13:15:30Z
          - ~
          - http://www.w3.org/2001/XMLSchema#dateTime
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
  variables: []
---
- ORDER BY with expression
- |2
  		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  		PREFIX	dcterms: <http://purl.org/dc/terms/>
  		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  		PREFIX	xsd: <http://www.w3.org/2001/XMLSchema#>
  		SELECT	?image ?point ?lat
  		WHERE	{
  					?point geo:lat ?lat .
  					?image ?pred ?point .
  		}
  		ORDER BY ASC( xsd:decimal( ?lat ) )
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
    xsd: http://www.w3.org/2001/XMLSchema#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
        -
          - ASC
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2001/XMLSchema#decimal
            - !!perl/array:RDF::Query::Node::Variable
              - lat
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- triple pattern with trailing internal '.'
- |
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX cyc: <http://www.cyc.com/2004/06/04/cyc#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  PREFIX dc: <http://purl.org/dc/elements/1.1/>
  SELECT ?place ?img ?date
  WHERE {
  	?region foaf:name "Maine" .
  	?p cyc:inRegion ?region; foaf:name ?place .
  	?img dcterms:spatial ?p .
  	?img dc:date ?date;  rdf:type foaf:Image .
  }
  ORDER BY DESC(?date)
  LIMIT 10
- method: SELECT
  namespaces:
    cyc: http://www.cyc.com/2004/06/04/cyc#
    dc: http://purl.org/dc/elements/1.1/
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Limit
      - !!perl/array:RDF::Query::Algebra::Project
        - !!perl/array:RDF::Query::Algebra::Sort
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - region
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Literal
                  - Maine
              - !!perl/array:RDF::Query::Algebra::Triple
                - &1 !!perl/array:RDF::Query::Node::Variable
                  - p
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://www.cyc.com/2004/06/04/cyc#inRegion
                - !!perl/array:RDF::Query::Node::Variable
                  - region
              - !!perl/array:RDF::Query::Algebra::Triple
                - *1
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - place
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - img
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/terms/spatial
                - !!perl/array:RDF::Query::Node::Variable
                  - p
              - !!perl/array:RDF::Query::Algebra::Triple
                - &2 !!perl/array:RDF::Query::Node::Variable
                  - img
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://purl.org/dc/elements/1.1/date
                - !!perl/array:RDF::Query::Node::Variable
                  - date
              - !!perl/array:RDF::Query::Algebra::Triple
                - *2
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/Image
          -
            - DESC
            - !!perl/array:RDF::Query::Node::Variable
              - date
        - &3
          - !!perl/array:RDF::Query::Node::Variable
            - place
          - !!perl/array:RDF::Query::Node::Variable
            - img
          - !!perl/array:RDF::Query::Node::Variable
            - date
      - 10
  variables: *3
---
- "[bug] query with predicate starting with 'a' (confused with { ?subj a ?type})"
- |2
  			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  			PREFIX cyc: <http://www.cyc.com/2004/06/04/cyc#>
  			PREFIX dcterms: <http://purl.org/dc/terms/>
  			PREFIX dc: <http://purl.org/dc/elements/1.1/>
  			PREFIX album: <http://kasei.us/e/ns/album#>
  			PREFIX p: <http://www.usefulinc.com/picdiary/>
  			SELECT ?img ?date
  			WHERE {
  				<http://kasei.us/pictures/parties/19991205-Tims_Party/> album:image ?img .
  				?img dc:date ?date ; rdf:type foaf:Image .
  			}
  			ORDER BY DESC(?date)
- method: SELECT
  namespaces:
    album: http://kasei.us/e/ns/album#
    cyc: http://www.cyc.com/2004/06/04/cyc#
    dc: http://purl.org/dc/elements/1.1/
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    p: http://www.usefulinc.com/picdiary/
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://kasei.us/pictures/parties/19991205-Tims_Party/
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://kasei.us/e/ns/album#image
              - !!perl/array:RDF::Query::Node::Variable
                - img
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - img
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://purl.org/dc/elements/1.1/date
              - !!perl/array:RDF::Query::Node::Variable
                - date
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Image
        -
          - DESC
          - !!perl/array:RDF::Query::Node::Variable
            - date
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - img
        - !!perl/array:RDF::Query::Node::Variable
          - date
  variables: *2
---
- dawg/simple/01
- |2
  		PREFIX : <http://example.org/data/>
  		
  		SELECT *
  		WHERE { :x ?p ?q . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/data/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/data/x
            - !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Variable
              - q
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - p
        - !!perl/array:RDF::Query::Node::Variable
          - q
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - p
    - !!perl/array:RDF::Query::Node::Variable
      - q
---
- single triple with comment; dawg/data/part1
- |2
  		# Get name, and optionally the mbox, of each person
  		
  		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  		
  		SELECT ?name ?mbox
  		WHERE
  		  { ?person foaf:name ?name .
  			OPTIONAL { ?person foaf:mbox ?mbox}
  		  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/mbox
                - !!perl/array:RDF::Query::Node::Variable
                  - mbox
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - name
        - !!perl/array:RDF::Query::Node::Variable
          - mbox
  variables: *1
---
- ask query
- |
  ASK {
    ?node a <http://kasei.us/e/ns/mt/blog> .
  }
- method: ASK
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
      - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - node
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://kasei.us/e/ns/mt/blog
  variables: []
---
- blank-pred-blank
- |
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name
  WHERE {
    [ foaf:name ?name ] foaf:maker []
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/maker
            - !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- Filter with unary-plus
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?image ?point ?lat
  WHERE	{
  			?point geo:lat ?lat .
  			?image ?pred ?point .
  			FILTER( ?lat > +52 )
  }
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - '>'
          - !!perl/array:RDF::Query::Node::Variable
            - lat
          - !!perl/array:RDF::Query::Node::Literal
            - +52
            - ~
            - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- Filter with isIRI
- |
  PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	dcterms: <http://purl.org/dc/terms/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?image ?point ?lat
  WHERE	{
  			?point geo:lat ?lat .
  			?image ?pred ?point .
  			FILTER( isIRI(?image) )
  }
- method: SELECT
  namespaces:
    dcterms: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:isiri
          - !!perl/array:RDF::Query::Node::Variable
            - image
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - point
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/2003/01/geo/wgs84_pos#lat
              - !!perl/array:RDF::Query::Node::Variable
                - lat
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - image
              - !!perl/array:RDF::Query::Node::Variable
                - pred
              - !!perl/array:RDF::Query::Node::Variable
                - point
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - image
        - !!perl/array:RDF::Query::Node::Variable
          - point
        - !!perl/array:RDF::Query::Node::Variable
          - lat
  variables: *1
---
- 'xsd:double'
- |
  PREFIX dc:  <http://purl.org/dc/elements/1.1/>
  SELECT ?node
  WHERE {
    ?node dc:identifier 1e4 .
  }
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - node
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/identifier
            - !!perl/array:RDF::Query::Node::Literal
              - 1e4
              - ~
              - http://www.w3.org/2001/XMLSchema#double
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - node
  variables: *1
---
- boolean literal
- |
  PREFIX dc:  <http://purl.org/dc/elements/1.1/>
  SELECT ?node
  WHERE {
    ?node dc:identifier true .
  }
- method: SELECT
  namespaces:
    dc: http://purl.org/dc/elements/1.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - node
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/identifier
            - !!perl/array:RDF::Query::Node::Literal
              - true
              - ~
              - http://www.w3.org/2001/XMLSchema#boolean
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - node
  variables: *1
---
- select with ORDER BY function call
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	: <http://example.com/>
  SELECT	?name
  WHERE	{
  			?person a foaf:Person; foaf:name ?name
  		}
  ORDER BY :foo(?name)
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    __DEFAULT__: http://example.com/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - &1 !!perl/array:RDF::Query::Node::Variable
                - person
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::Triple
              - *1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://xmlns.com/foaf/0.1/name
              - !!perl/array:RDF::Query::Node::Variable
                - name
        -
          - ASC
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.com/foo
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- select with bnode object as second pred-obj
- |
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name
  WHERE {
    ?r foaf:name ?name ; foaf:maker [ a foaf:Person ]
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Person
          - !!perl/array:RDF::Query::Algebra::Triple
            - &2 !!perl/array:RDF::Query::Node::Variable
              - r
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Algebra::Triple
            - *2
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/maker
            - *1
      - &3
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *3
---
- select with qname with '-2' suffix
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	wn: <http://xmlns.com/wordnet/1.6/>
  SELECT	?thing
  WHERE	{
  	?image a foaf:Image ;
  		foaf:depicts ?thing .
  	?thing a wn:Flower-2 .
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    wn: http://xmlns.com/wordnet/1.6/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - image
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Image
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/depicts
            - !!perl/array:RDF::Query::Node::Variable
              - thing
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - thing
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/wordnet/1.6/Flower-2
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - thing
  variables: *2
---
- select with qname with underscore
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?name
  WHERE	{
  	?p a foaf:Person ;
  		foaf:mbox_sha1sum "2057969209f1dfdad832de387cf13e6ff8c93b12" ;
  		foaf:name ?name .
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/Person
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/mbox_sha1sum
            - !!perl/array:RDF::Query::Node::Literal
              - 2057969209f1dfdad832de387cf13e6ff8c93b12
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
  variables: *2
---
- construct with one construct triple
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  CONSTRUCT { ?person foaf:name ?name }
  WHERE	{ ?person foaf:firstName ?name }
- method: CONSTRUCT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Construct
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/firstName
            - !!perl/array:RDF::Query::Node::Variable
              - name
      -
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/name
          - !!perl/array:RDF::Query::Node::Variable
            - name
---
- construct with two construct triples
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  CONSTRUCT { ?person foaf:name ?name . ?person a foaf:Person }
  WHERE	{ ?person foaf:firstName ?name }
- method: CONSTRUCT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Construct
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/firstName
            - !!perl/array:RDF::Query::Node::Variable
              - name
      -
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/name
          - !!perl/array:RDF::Query::Node::Variable
            - name
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/Person
---
- construct with three construct triples
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  CONSTRUCT { ?person a foaf:Person  . ?person foaf:name ?name . ?person foaf:firstName ?name }
  WHERE	{ ?person foaf:firstName ?name }
- method: CONSTRUCT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Construct
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/firstName
            - !!perl/array:RDF::Query::Node::Variable
              - name
      -
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/Person
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/name
          - !!perl/array:RDF::Query::Node::Variable
            - name
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - person
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://xmlns.com/foaf/0.1/firstName
          - !!perl/array:RDF::Query::Node::Variable
            - name
---
- select with triple-optional-triple
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  SELECT	?person ?nick ?page
  WHERE	{
  	?person foaf:name "Gregory Todd Williams" .
  	OPTIONAL { ?person foaf:nick ?nick } .
  	?person foaf:homepage ?page
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Literal
                  - Gregory Todd Williams
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/nick
                - !!perl/array:RDF::Query::Node::Variable
                  - nick
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - person
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/homepage
            - !!perl/array:RDF::Query::Node::Variable
              - page
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - person
        - !!perl/array:RDF::Query::Node::Variable
          - nick
        - !!perl/array:RDF::Query::Node::Variable
          - page
  variables: *1
---
- select with FROM
- |
  PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  SELECT	?lat ?long
  FROM	<http://kasei.us/code/rdf-query/test-data/greenwich.rdf>
  WHERE	{
  	?point a geo:Point ;
  		geo:lat ?lat ;
  		geo:long ?long .
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    geo: http://www.w3.org/2003/01/geo/wgs84_pos#
  sources:
    -
      - !!perl/array:RDF::Query::Node::Resource
        - URI
        - http://kasei.us/code/rdf-query/test-data/greenwich.rdf
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Variable
              - point
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2003/01/geo/wgs84_pos#Point
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2003/01/geo/wgs84_pos#lat
            - !!perl/array:RDF::Query::Node::Variable
              - lat
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2003/01/geo/wgs84_pos#long
            - !!perl/array:RDF::Query::Node::Variable
              - long
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - lat
        - !!perl/array:RDF::Query::Node::Variable
          - long
  variables: *2
---
- select with graph-triple-triple
- |
  # select all the email addresses ever held by the person
  # who held a given email address on 2007-01-01
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX t: <http://www.w3.org/2006/09/time#>
  SELECT ?mbox WHERE {
  	GRAPH ?time { ?p foaf:mbox <mailto:gtw@cs.umd.edu> } .
  	?time t:inside "2007-01-01" .
  	?p foaf:mbox ?mbox .
  }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    t: http://www.w3.org/2006/09/time#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::NamedGraph
          - GRAPH
          - &1 !!perl/array:RDF::Query::Node::Variable
            - time
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - p
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/mbox
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - mailto:gtw@cs.umd.edu
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - time
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2006/09/time#inside
            - !!perl/array:RDF::Query::Node::Literal
              - 2007-01-01
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/mbox
            - !!perl/array:RDF::Query::Node::Variable
              - mbox
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - mbox
  variables: *2
---
- (DAWG) syn-leading-digits-in-prefixed-names.rq
- |
  PREFIX dob: <http://placetime.com/interval/gregorian/1977-01-18T04:00:00Z/P> 
  PREFIX t: <http://www.ai.sri.com/daml/ontologies/time/Time.daml#>
  PREFIX dc: <http://purl.org/dc/elements/1.1/>
  SELECT ?desc
  WHERE  { 
    dob:1D a t:ProperInterval;
           dc:description ?desc.
  }
- method: SELECT
  namespaces:
    dob: http://placetime.com/interval/gregorian/1977-01-18T04:00:00Z/P
    t: http://www.ai.sri.com/daml/ontologies/time/Time.daml#
    dc: http://purl.org/dc/elements/1.1/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://placetime.com/interval/gregorian/1977-01-18T04:00:00Z/P1D
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.ai.sri.com/daml/ontologies/time/Time.daml#ProperInterval
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://purl.org/dc/elements/1.1/description
            - !!perl/array:RDF::Query::Node::Variable
              - desc
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - desc
  variables: *2
---
- (DAWG) syn-07.rq
- |
  # Trailing ;
  PREFIX :   <http://example/ns#>
  SELECT * WHERE
  { :s :p :o ; FILTER(?x) }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Node::Variable
          - x
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example/ns#s
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example/ns#p
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example/ns#o
      - &1 []
  variables: *1
---
- (DAWG) syn-08.rq
- |
  # Broken ;
  PREFIX :   <http://example/ns#>
  SELECT * WHERE
  { :s :p :o ; . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/ns#s
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/ns#p
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/ns#o
      - &1 []
  variables: []
---
- (DAWG) syn-11.rq
- |
  PREFIX : <http://example.org/>
  SELECT *
  WHERE
  {
    _:a ?p ?v .  FILTER(true) . [] ?q _:a
  }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Node::Literal
          - true
          - ~
          - http://www.w3.org/2001/XMLSchema#boolean
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Blank
                - BLANK
                - a
              - !!perl/array:RDF::Query::Node::Variable
                - p
              - !!perl/array:RDF::Query::Node::Variable
                - v
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Blank
                - BLANK
                - a1
              - !!perl/array:RDF::Query::Node::Variable
                - q
              - !!perl/array:RDF::Query::Node::Blank
                - BLANK
                - a
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - p
        - !!perl/array:RDF::Query::Node::Variable
          - v
        - !!perl/array:RDF::Query::Node::Variable
          - q
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - p
    - !!perl/array:RDF::Query::Node::Variable
      - v
    - !!perl/array:RDF::Query::Node::Variable
      - q
---
- (DAWG) syntax-form-describe01.rq
- |
  DESCRIBE <u>
- method: DESCRIBE
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
  variables:
    - !!perl/array:RDF::Query::Node::Resource
      - URI
      - u
---
- (DAWG) syntax-form-construct04.rq
- |
  PREFIX  rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  CONSTRUCT { [] rdf:subject ?s ;
                 rdf:predicate ?p ;
                 rdf:object ?o . }
  WHERE {?s ?p ?o}
- method: CONSTRUCT
  namespaces:
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Construct
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - s
            - !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Variable
              - o
      -
        - !!perl/array:RDF::Query::Algebra::Triple
          - &1 !!perl/array:RDF::Query::Node::Blank
            - BLANK
            - a1
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#subject
          - !!perl/array:RDF::Query::Node::Variable
            - s
        - !!perl/array:RDF::Query::Algebra::Triple
          - *1
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate
          - !!perl/array:RDF::Query::Node::Variable
            - p
        - !!perl/array:RDF::Query::Algebra::Triple
          - *1
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - http://www.w3.org/1999/02/22-rdf-syntax-ns#object
          - !!perl/array:RDF::Query::Node::Variable
            - o
---
- (DAWG) syntax-lists-02.rq
- |
  PREFIX : <http://example.org/ns#> 
  SELECT * WHERE { ?x :p ( ?z ) }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Variable
              - z
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#p
            - *1
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - z
        - !!perl/array:RDF::Query::Node::Variable
          - x
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - z
    - !!perl/array:RDF::Query::Node::Variable
      - x
---
- (DAWG) syntax-qname-03.rq
- |
  PREFIX : <http://example.org/ns#> 
  SELECT *
  WHERE { :_1 :p.rdf :z.z . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#_1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#p.rdf
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#z.z
      - &1 []
  variables: []
---
- (DAWG) syntax-qname-08.rq
- |
  BASE   <http://example.org/>
  PREFIX :  <#>
  PREFIX x.y:  <x#>
  SELECT *
  WHERE { :a.b  x.y:  : . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/#
    x.y: http://example.org/x#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#a.b
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/x#
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#
      - &1 []
  base: !!perl/array:RDF::Query::Node::Resource
    - URI
    - http://example.org/
  variables: []
---
- (DAWG) syntax-lit-07.rq
- |
  BASE   <http://example.org/>
  PREFIX :  <#> 
  SELECT * WHERE { :x :p 123 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#p
            - !!perl/array:RDF::Query::Node::Literal
              - 123
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &1 []
  base: !!perl/array:RDF::Query::Node::Resource
    - URI
    - http://example.org/
  variables: []
---
- (DAWG) syntax-lit-08.rq
- |
  BASE   <http://example.org/>
  PREFIX :  <#> 
  SELECT * WHERE { :x :p 123. . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#p
            - !!perl/array:RDF::Query::Node::Literal
              - 123.
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
      - &1 []
  base: !!perl/array:RDF::Query::Node::Resource
    - URI
    - http://example.org/
  variables: []
---
- (DAWG) syntax-lit-12.rq
- |
  BASE   <http://example.org/>
  PREFIX :  <#> 
  SELECT * WHERE { :x :p '''Long''\'Literal''' }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#p
            - !!perl/array:RDF::Query::Node::Literal
              - Long'''Literal
      - &1 []
  base: !!perl/array:RDF::Query::Node::Resource
    - URI
    - http://example.org/
  variables: []
---
- (DAWG) syntax-lit-13.rq
- |
  BASE   <http://example.org/>
  PREFIX :  <#> 
  SELECT * WHERE { :x :p """Long\"""Literal""" }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/#p
            - !!perl/array:RDF::Query::Node::Literal
              - Long"""Literal
      - &1 []
  base: !!perl/array:RDF::Query::Node::Resource
    - URI
    - http://example.org/
  variables: []
---
- (DAWG) syntax-general-07.rq
- |
  SELECT * WHERE { <a><b>+1.0 }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - a
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - b
            - !!perl/array:RDF::Query::Node::Literal
              - +1.0
              - ~
              - http://www.w3.org/2001/XMLSchema#decimal
      - &1 []
  variables: []
---
- (DAWG) syntax-general-09.rq
- |
  SELECT * WHERE { <a><b>1.0e0 }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - a
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - b
            - !!perl/array:RDF::Query::Node::Literal
              - 1.0e0
              - ~
              - http://www.w3.org/2001/XMLSchema#double
      - &1 []
  variables: []
---
- (DAWG) syntax-general-10.rq
- |
  SELECT * WHERE { <a><b>+1.0e+1 }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - a
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - b
            - !!perl/array:RDF::Query::Node::Literal
              - +1.0e+1
              - ~
              - http://www.w3.org/2001/XMLSchema#double
      - &1 []
  variables: []
---
- (DAWG) syntax-lists-03.rq
- |
  PREFIX : <http://example.org/>
  SELECT * WHERE { ( 
  ) :p 1 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/p
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &1 []
  variables: []
---
- (DAWG) syntax-lists-04.rq
- |
  PREFIX : <http://example.org/>
  SELECT * WHERE { ( 1 2
  ) :p 1 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 2
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/p
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &5 []
  variables: []
---
- (DAWG) syntax-lists-02.rq
- |
  PREFIX : <http://example.org/>
  SELECT * WHERE { ( ) :p 1 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/p
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &1 []
  variables: []
---
- (DAWG) syntax-lists-04.rq
- |
  PREFIX : <http://example.org/>
  SELECT * WHERE { ( 1 2
  ) :p 1 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - &2 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#first
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - &3 !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#rest
            - &4 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *2
            - !!perl/array:RDF::Query::Node::Literal
              - 2
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::Triple
            - *4
            - *3
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#nil
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/p
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &5 []
  variables: []
---
- (DAWG) dawg-eval
- |
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX ex: <http://example.com/#>
  SELECT ?val
  WHERE {
    ex:foo rdf:value ?val .
    FILTER regex(str(?val), "example\\.com")
  }
- method: SELECT
  namespaces:
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
    ex: http://example.com/#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:regex
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - sparql:str
            - !!perl/array:RDF::Query::Node::Variable
              - val
          - !!perl/array:RDF::Query::Node::Literal
            - example\.com
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.com/#foo
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://www.w3.org/1999/02/22-rdf-syntax-ns#value
              - !!perl/array:RDF::Query::Node::Variable
                - val
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - val
  variables: *1
---
- (DAWG) dawg-eval: sameTerm
- |
  PREFIX : <http://example.org/things#>
  SELECT * {
    ?x1 :p ?v1 .
    ?x2 :p ?v2 .
    FILTER ( !sameTerm(?v1, ?v2) && ?v1 = ?v2 )
  } 
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/things#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:logical-and
          - !!perl/array:RDF::Query::Expression::Unary
            - '!'
            - !!perl/array:RDF::Query::Expression::Function
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - sparql:sameterm
              - !!perl/array:RDF::Query::Node::Variable
                - v1
              - !!perl/array:RDF::Query::Node::Variable
                - v2
          - !!perl/array:RDF::Query::Expression::Binary
            - ==
            - !!perl/array:RDF::Query::Node::Variable
              - v1
            - !!perl/array:RDF::Query::Node::Variable
              - v2
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/things#p
              - !!perl/array:RDF::Query::Node::Variable
                - v1
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x2
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/things#p
              - !!perl/array:RDF::Query::Node::Variable
                - v2
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - x1
        - !!perl/array:RDF::Query::Node::Variable
          - v1
        - !!perl/array:RDF::Query::Node::Variable
          - x2
        - !!perl/array:RDF::Query::Node::Variable
          - v2
  variables: *1
---
- (DAWG) dawg-eval: basic/manifest#term-8
- |
  PREFIX : <http://example.org/ns#>
  PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
  # DOT is part of the decimal.
  SELECT * { :x ?p +5 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
    xsd: http://www.w3.org/2001/XMLSchema#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#x
            - !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Literal
              - +5
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - p
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - p
---
- (DAWG) dawg-eval: algebra/manifest#filter-nested-2
- |
  PREFIX : <http://example/>
  SELECT ?v { :x :p ?v . { FILTER(?v = 1) } }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/p
            - !!perl/array:RDF::Query::Node::Variable
              - v
        - !!perl/array:RDF::Query::Algebra::Filter
          - FILTER
          - !!perl/array:RDF::Query::Expression::Binary
            - ==
            - !!perl/array:RDF::Query::Node::Variable
              - v
            - !!perl/array:RDF::Query::Node::Literal
              - 1
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - v
  variables: *1
---
- (DAWG) dawg-eval: optional/manifest#dawg-optional-complex-4
- |
  PREFIX  foaf:   <http://xmlns.com/foaf/0.1/>
  PREFIX    ex:   <http://example.org/things#>
  SELECT ?name ?plan ?dept ?img
  FROM <...>
  FROM NAMED <...>
  WHERE { 
  	?person foaf:name ?name  
  	{ ?person ex:healthplan ?plan } UNION { ?person ex:department ?dept } 
  	OPTIONAL { 
  		?person a foaf:Person
  		GRAPH ?g { 
  			[] foaf:name ?name;
  			   foaf:depiction ?img 
  		} 
  	} 
  }
- method: SELECT
  namespaces:
    ex: http://example.org/things#
    foaf: http://xmlns.com/foaf/0.1/
  sources:
    -
      - !!perl/array:RDF::Query::Node::Resource
        - URI
        - ...
    -
      - !!perl/array:RDF::Query::Node::Resource
        - URI
        - ...
      - NAMED
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/name
                - !!perl/array:RDF::Query::Node::Variable
                  - name
            - !!perl/array:RDF::Query::Algebra::Union
              - UNION
              - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - !!perl/array:RDF::Query::Node::Variable
                      - person
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://example.org/things#healthplan
                    - !!perl/array:RDF::Query::Node::Variable
                      - plan
              - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - !!perl/array:RDF::Query::Node::Variable
                      - person
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://example.org/things#department
                    - !!perl/array:RDF::Query::Node::Variable
                      - dept
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - person
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://xmlns.com/foaf/0.1/Person
            - !!perl/array:RDF::Query::Algebra::NamedGraph
              - GRAPH
              - &1 !!perl/array:RDF::Query::Node::Variable
                - g
              - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
                - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - &2 !!perl/array:RDF::Query::Node::Blank
                      - BLANK
                      - a1
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://xmlns.com/foaf/0.1/name
                    - !!perl/array:RDF::Query::Node::Variable
                      - name
                  - !!perl/array:RDF::Query::Algebra::Triple
                    - *2
                    - !!perl/array:RDF::Query::Node::Resource
                      - URI
                      - http://xmlns.com/foaf/0.1/depiction
                    - !!perl/array:RDF::Query::Node::Variable
                      - img
      - &3
        - !!perl/array:RDF::Query::Node::Variable
          - name
        - !!perl/array:RDF::Query::Node::Variable
          - plan
        - !!perl/array:RDF::Query::Node::Variable
          - dept
        - !!perl/array:RDF::Query::Node::Variable
          - img
  variables: *3
---
- (DAWG) dawg-eval: i18n/manifest#kanji-1
- |
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX 食: <http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#>
  SELECT ?name ?food WHERE {
    [ foaf:name ?name ;
      食:食べる ?food ] . }
- method: SELECT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    食: http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - &1 !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://xmlns.com/foaf/0.1/name
            - !!perl/array:RDF::Query::Node::Variable
              - name
          - !!perl/array:RDF::Query::Algebra::Triple
            - *1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる
            - !!perl/array:RDF::Query::Node::Variable
              - food
      - &2
        - !!perl/array:RDF::Query::Node::Variable
          - name
        - !!perl/array:RDF::Query::Node::Variable
          - food
  variables: *2
---
- (DAWG) dawg-syntax: syntax-sparql4/manifest#syn-10
- |
  PREFIX : <http://example.org/>
  SELECT *
  WHERE
  {
    { _:a ?p ?v .  _:a ?q _:a } UNION { _:b ?q _:c }
  }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Union
          - UNION
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Blank
                  - BLANK
                  - a
                - !!perl/array:RDF::Query::Node::Variable
                  - p
                - !!perl/array:RDF::Query::Node::Variable
                  - v
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Blank
                  - BLANK
                  - a
                - !!perl/array:RDF::Query::Node::Variable
                  - q
                - !!perl/array:RDF::Query::Node::Blank
                  - BLANK
                  - a
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Blank
                  - BLANK
                  - b
                - !!perl/array:RDF::Query::Node::Variable
                  - q
                - !!perl/array:RDF::Query::Node::Blank
                  - BLANK
                  - c
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - p
        - !!perl/array:RDF::Query::Node::Variable
          - v
        - !!perl/array:RDF::Query::Node::Variable
          - q
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - p
    - !!perl/array:RDF::Query::Node::Variable
      - v
    - !!perl/array:RDF::Query::Node::Variable
      - q
---
- (DAWG) dawg-syntax: syntax-sparql1/manifest#syntax-pat-04
- |
  PREFIX : <http://example.org/ns#> 
  SELECT *
  {
    OPTIONAL{:x :y :z} 
    ?a :b :c 
    { :x1 :y1 :z1 } UNION { :x2 :y2 :z2 }
  }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#y
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#z
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - a
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#b
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#c
        - !!perl/array:RDF::Query::Algebra::Union
          - UNION
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#x1
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#y1
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#z1
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#x2
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#y2
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#z2
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - a
  variables:
    - !!perl/array:RDF::Query::Node::Variable
      - a
---
- (DAWG) dawg-syntax: syntax-sparql1/manifest#syntax-struct-10
- |
  PREFIX :  <http://example.org/ns#> 
  SELECT *
  { OPTIONAL { :a :b :c } . ?x ?y ?z }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Optional
          - OPTIONAL
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#a
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#b
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - http://example.org/ns#c
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - x
            - !!perl/array:RDF::Query::Node::Variable
              - y
            - !!perl/array:RDF::Query::Node::Variable
              - z
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - x
        - !!perl/array:RDF::Query::Node::Variable
          - y
        - !!perl/array:RDF::Query::Node::Variable
          - z
  variables: *1
---
- (DAWG) dawg-syntax: expr-equals/manifest#eq-2-1
- |
  PREFIX  xsd: <http://www.w3.org/2001/XMLSchema#>
  PREFIX  : <http://example.org/things#>
  SELECT  ?v1 ?v2
  WHERE
      { ?x1 :p ?v1 .
        ?x2 :p ?v2 . 
        FILTER ( ?v1 = ?v2 ) .
      }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/things#
    xsd: http://www.w3.org/2001/XMLSchema#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Node::Variable
            - v1
          - !!perl/array:RDF::Query::Node::Variable
            - v2
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x1
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/things#p
              - !!perl/array:RDF::Query::Node::Variable
                - v1
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - x2
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/things#p
              - !!perl/array:RDF::Query::Node::Variable
                - v2
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - v1
        - !!perl/array:RDF::Query::Node::Variable
          - v2
  variables: *1
---
- (DAWG) dawg-syntax: expr-ops/manifest#minus-1
- |
  PREFIX : <http://example.org/>
  SELECT ?s WHERE {
      ?s :p ?o .
      ?s2 :p ?o2 .
      FILTER(?o - ?o2 = 3) .
  }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Filter
        - FILTER
        - !!perl/array:RDF::Query::Expression::Binary
          - ==
          - !!perl/array:RDF::Query::Expression::Binary
            - -
            - !!perl/array:RDF::Query::Node::Variable
              - o
            - !!perl/array:RDF::Query::Node::Variable
              - o2
          - !!perl/array:RDF::Query::Node::Literal
            - 3
            - ~
            - http://www.w3.org/2001/XMLSchema#integer
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - s
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/p
              - !!perl/array:RDF::Query::Node::Variable
                - o
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - s2
              - !!perl/array:RDF::Query::Node::Resource
                - URI
                - http://example.org/p
              - !!perl/array:RDF::Query::Node::Variable
                - o2
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
  variables: *1
---
- (DAWG) dawg-syntax: syntax-qname-04.rq
- |
  PREFIX :  <http://example.org/ns#> 
  PREFIX a: <http://example.org/ns2#> 
  SELECT *
  WHERE { : a: :a . : : : . }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
    a: http://example.org/ns2#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns2#
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#a
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#
      - &1 []
  variables: *1
---
- (DAWG) dawg-syntax: syntax-union-02.rq
- |
  PREFIX : <http://example.org/ns#>
  SELECT *
  {
    { ?s ?p ?o } UNION { ?a ?b ?c } UNION { ?r ?s ?t }
  }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Union
          - UNION
          - !!perl/array:RDF::Query::Algebra::Union
            - UNION
            - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
              - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                - !!perl/array:RDF::Query::Algebra::Triple
                  - !!perl/array:RDF::Query::Node::Variable
                    - s
                  - !!perl/array:RDF::Query::Node::Variable
                    - p
                  - !!perl/array:RDF::Query::Node::Variable
                    - o
            - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
              - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
                - !!perl/array:RDF::Query::Algebra::Triple
                  - !!perl/array:RDF::Query::Node::Variable
                    - a
                  - !!perl/array:RDF::Query::Node::Variable
                    - b
                  - !!perl/array:RDF::Query::Node::Variable
                    - c
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Triple
                - !!perl/array:RDF::Query::Node::Variable
                  - r
                - !!perl/array:RDF::Query::Node::Variable
                  - s
                - !!perl/array:RDF::Query::Node::Variable
                  - t
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
        - !!perl/array:RDF::Query::Node::Variable
          - p
        - !!perl/array:RDF::Query::Node::Variable
          - o
        - !!perl/array:RDF::Query::Node::Variable
          - a
        - !!perl/array:RDF::Query::Node::Variable
          - b
        - !!perl/array:RDF::Query::Node::Variable
          - c
        - !!perl/array:RDF::Query::Node::Variable
          - r
        - !!perl/array:RDF::Query::Node::Variable
          - t
  variables: *1
---
- (DAWG) dawg-syntax: syntax-order-06.rq
- |
  PREFIX :      <http://example.org/ns#> 
  SELECT *
  { ?s ?p ?o }
  ORDER BY 
    DESC(?o+57) :func2(?o) ASC(?s)
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/ns#
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::Sort
        - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
          - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
            - !!perl/array:RDF::Query::Algebra::Triple
              - !!perl/array:RDF::Query::Node::Variable
                - s
              - !!perl/array:RDF::Query::Node::Variable
                - p
              - !!perl/array:RDF::Query::Node::Variable
                - o
        -
          - DESC
          - !!perl/array:RDF::Query::Expression::Binary
            - +
            - !!perl/array:RDF::Query::Node::Variable
              - o
            - !!perl/array:RDF::Query::Node::Literal
              - 57
              - ~
              - http://www.w3.org/2001/XMLSchema#integer
        -
          - ASC
          - !!perl/array:RDF::Query::Expression::Function
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/ns#func2
            - !!perl/array:RDF::Query::Node::Variable
              - o
        -
          - ASC
          - !!perl/array:RDF::Query::Node::Variable
            - s
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
        - !!perl/array:RDF::Query::Node::Variable
          - p
        - !!perl/array:RDF::Query::Node::Variable
          - o
  variables: *1
---
- (DAWG) dawg-syntax: syntax-bnode-02.rq
- |
  PREFIX : <http://example.org/>
  # Tab
  SELECT * WHERE { [ ] :p [
  	] }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example.org/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a1
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example.org/p
            - !!perl/array:RDF::Query::Node::Blank
              - BLANK
              - a2
      - &1 []
  variables: []
---
- (DAWG) dawg-syntax: syntax-esc-04.rq
- |
  PREFIX : <http://example/> 
  SELECT *
  WHERE { <\u0078> :\u0070 ?xx\u0078 }
- method: SELECT
  namespaces:
    __DEFAULT__: http://example/
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://example/p
            - !!perl/array:RDF::Query::Node::Variable
              - xxx
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - xxx
  variables: *1
---
- CONSTRUCT with LIMIT (github pull request 17, from kjetilk)
- |
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
  PREFIX  foaf:       <http://xmlns.com/foaf/0.1/>
  CONSTRUCT { ?s ?p ?o . }
  WHERE {
    ?s ?p ?o .
  } LIMIT 5
- method: CONSTRUCT
  namespaces:
    foaf: http://xmlns.com/foaf/0.1/
    rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#
  sources: []
  options:
    limit: 5
  triples:
    - !!perl/array:RDF::Query::Algebra::Construct
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - s
            - !!perl/array:RDF::Query::Node::Variable
              - p
            - !!perl/array:RDF::Query::Node::Variable
              - o
      -
        - !!perl/array:RDF::Query::Algebra::Triple
          - !!perl/array:RDF::Query::Node::Variable
            - s
          - !!perl/array:RDF::Query::Node::Variable
            - p
          - !!perl/array:RDF::Query::Node::Variable
            - o
---
- INSERT-DELETE-USING-WHERE
- |
  DELETE { GRAPH <g1> { ?x <b> <c> } } INSERT { GRAPH <g1> { ?x <y> <z> } } USING <g1> WHERE { ?x a <Foo> }
- method: UPDATE
  custom_update_dataset: 1
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Update
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::NamedGraph
          - GRAPH
          - &1 !!perl/array:RDF::Query::Node::Resource
            - URI
            - g1
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Quad
                - !!perl/array:RDF::Query::Node::Variable
                  - x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - b
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - c
                - *1
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::NamedGraph
          - GRAPH
          - &2 !!perl/array:RDF::Query::Node::Resource
            - URI
            - g1
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
            - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
              - !!perl/array:RDF::Query::Algebra::Quad
                - !!perl/array:RDF::Query::Node::Variable
                  - x
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - y
                - !!perl/array:RDF::Query::Node::Resource
                  - URI
                  - z
                - *2
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::BasicGraphPattern
          - !!perl/array:RDF::Query::Algebra::Triple
            - !!perl/array:RDF::Query::Node::Variable
              - x
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - http://www.w3.org/1999/02/22-rdf-syntax-ns#type
            - !!perl/array:RDF::Query::Node::Resource
              - URI
              - Foo
      - default:
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - g1
      - 0
