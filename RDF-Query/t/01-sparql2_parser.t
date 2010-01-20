#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 4;
use YAML;
use Data::Dumper;
use Scalar::Util qw(reftype);
use RDF::Query::Node;

use_ok( 'RDF::Query::Parser::SPARQL2' );

################################################################################
Log::Log4perl::init( \q[
	log4perl.category.rdf.query.parser          = TRACE, Screen
	
	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
	log4perl.appender.Screen.stderr  = 0
	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
] );
################################################################################

my $parser	= RDF::Query::Parser::SPARQL2->new();
isa_ok( $parser, 'RDF::Query::Parser::SPARQL2' );


my (@data)	= YAML::Load(do { local($/) = undef; <DATA> });
foreach (@data) {
	next unless (reftype($_) eq 'ARRAY');
	my ($name, $sparql, $correct)	= @$_;
	my $parsed	= $parser->parse( $sparql );
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
- EXISTS graph pattern
- |
  SELECT *
  WHERE {
    EXISTS { ?s a <type> }
  }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Exists
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
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
          - 0
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
  variables: *1
---
- NOT EXISTS graph pattern
- |
  SELECT *
  WHERE {
    NOT EXISTS { ?s a <type> }
  }
- method: SELECT
  namespaces: {}
  sources: []
  triples:
    - !!perl/array:RDF::Query::Algebra::Project
      - !!perl/array:RDF::Query::Algebra::GroupGraphPattern
        - !!perl/array:RDF::Query::Algebra::Exists
          - !!perl/array:RDF::Query::Algebra::GroupGraphPattern []
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
          - 1
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
  variables: *1
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
        - !!perl/array:RDF::Query::Expression::Function
          - !!perl/array:RDF::Query::Node::Resource
            - URI
            - sparql:not-exists
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
      - &1
        - !!perl/array:RDF::Query::Node::Variable
          - s
  variables: *1
