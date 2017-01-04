#!/usr/bin/env perl
use strict;
use Test::More tests => 5;

use RDF::Query::Node qw(variable);
use_ok( 'RDF::Query::Parser::RDQL' );
my $parser	= new RDF::Query::Parser::RDQL (undef);
isa_ok( $parser, 'RDF::Query::Parser::RDQL' );

{
	my $rdql	= <<"END";
		SELECT
			?page
		WHERE
			(?person foaf:name "Gregory Todd Williams")
			(?person foaf:homepage ?page)
		USING
			rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
			foaf FOR <http://xmlns.com/foaf/0.1/>,
			dcterms FOR <http://purl.org/dc/terms/>,
			geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
	my $correct = {
		  'triples' => [
						 bless( [
								  bless( [
										   bless( [
													bless( [
															 'person'
														   ], 'RDF::Query::Node::Variable' ),
													bless( [
															 'URI',
															 'http://xmlns.com/foaf/0.1/name'
														   ], 'RDF::Query::Node::Resource' ),
													bless( [
															 'Gregory Todd Williams'
														   ], 'RDF::Query::Node::Literal' )
												  ], 'RDF::Query::Algebra::Triple' ),
										   bless( [
													bless( [
															 'person'
														   ], 'RDF::Query::Node::Variable' ),
													bless( [
															 'URI',
															 'http://xmlns.com/foaf/0.1/homepage'
														   ], 'RDF::Query::Node::Resource' ),
													bless( [
															 'page'
														   ], 'RDF::Query::Node::Variable' )
												  ], 'RDF::Query::Algebra::Triple' )
										 ], 'RDF::Query::Algebra::GroupGraphPattern' ),
								  [
									bless( [
											 'page'
										   ], 'RDF::Query::Node::Variable' )
								  ]
								], 'RDF::Query::Algebra::Project' )
					   ],
		  'sources' => undef,
		  'variables' => [
						bless( [
								 'page'
							   ], 'RDF::Query::Node::Variable' )
					  ],
		  'method' => 'SELECT',
		  'namespaces' => {
							'geo' => 'http://www.w3.org/2003/01/geo/wgs84_pos#',
							'foaf' => 'http://xmlns.com/foaf/0.1/',
							'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
							'dcterms' => 'http://purl.org/dc/terms/'
						  }
		};
	my $parsed	= $parser->parse( $rdql );
	is_deeply( $parsed, $correct, 'SELECT, WHERE, USING' );
}

{
	my $rdql	= <<"END";
		SELECT
				?image ?point ?lat
		WHERE
				(?point geo:lat ?lat)
				(?image ?pred ?point)
		AND
				(?pred == <http://purl.org/dc/terms/spatial> || ?pred == <http://xmlns.com/foaf/0.1/based_near>)
		AND
				?lat > 52.988674,
				?lat < 53.036526
		USING
				rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
				foaf FOR <http://xmlns.com/foaf/0.1/>,
				dcterms FOR <http://purl.org/dc/terms/>,
				geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
	my $correct = {
		method			=> 'SELECT',
		'triples'		=> [
						 bless( [
								  bless( [
										   'FILTER',
										   bless( [
													bless( [
															 'URI',
															 'sparql:logical-and'
														   ], 'RDF::Query::Node::Resource' ),
													bless( [
															 bless( [
																	  'URI',
																	  'sparql:logical-or'
																	], 'RDF::Query::Node::Resource' ),
															 bless( [
																	  '==',
																	  bless( [
																			   'pred'
																			 ], 'RDF::Query::Node::Variable' ),
																	  bless( [
																			   'URI',
																			   'http://purl.org/dc/terms/spatial'
																			 ], 'RDF::Query::Node::Resource' )
																	], 'RDF::Query::Expression::Binary' ),
															 bless( [
																	  '==',
																	  bless( [
																			   'pred'
																			 ], 'RDF::Query::Node::Variable' ),
																	  bless( [
																			   'URI',
																			   'http://xmlns.com/foaf/0.1/based_near'
																			 ], 'RDF::Query::Node::Resource' )
																	], 'RDF::Query::Expression::Binary' )
														   ], 'RDF::Query::Expression::Function' ),
													bless( [
															 '>',
															 bless( [
																	  'lat'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  '52.988674',
																	  undef,
																	  'http://www.w3.org/2001/XMLSchema#float'
																	], 'RDF::Query::Node::Literal' )
														   ], 'RDF::Query::Expression::Binary' )
												  ], 'RDF::Query::Expression::Function' ),
										   bless( [
													bless( [
															 bless( [
																	  'point'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  'URI',
																	  'http://www.w3.org/2003/01/geo/wgs84_pos#lat'
																	], 'RDF::Query::Node::Resource' ),
															 bless( [
																	  'lat'
																	], 'RDF::Query::Node::Variable' )
														   ], 'RDF::Query::Algebra::Triple' ),
													bless( [
															 bless( [
																	  'image'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  'pred'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  'point'
																	], 'RDF::Query::Node::Variable' )
														   ], 'RDF::Query::Algebra::Triple' )
												  ], 'RDF::Query::Algebra::GroupGraphPattern' )
										 ], 'RDF::Query::Algebra::Filter' ),
								  [
									bless( [
											 'image'
										   ], 'RDF::Query::Node::Variable' ),
									bless( [
											 'point'
										   ], 'RDF::Query::Node::Variable' ),
									bless( [
											 'lat'
										   ], 'RDF::Query::Node::Variable' )
								  ]
								], 'RDF::Query::Algebra::Project' )
					   ],
		'sources'		=> undef,
		'namespaces'	=> {'foaf' => 'http://xmlns.com/foaf/0.1/','geo' => 'http://www.w3.org/2003/01/geo/wgs84_pos#','dcterms' => 'http://purl.org/dc/terms/','rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'},
		'variables'		=> [variable('image'),variable('point'),variable('lat')]
	};
	my $parsed	= $parser->parse( $rdql );
	is_deeply( $parsed, $correct, 'VarUri EQ OR constraint, numeric comparison constraint' );
}


{
	my $rdql	= <<"END";
		SELECT
				?person ?homepage
		WHERE
				(?person foaf:name "Gregory Todd Williams")
				(?person foaf:homepage ?homepage)
		AND
				?homepage ~~ /kasei/
		USING
				rdf FOR <http://www.w3.org/1999/02/22-rdf-syntax-ns#>,
				foaf FOR <http://xmlns.com/foaf/0.1/>,
				dcterms FOR <http://purl.org/dc/terms/>,
				geo FOR <http://www.w3.org/2003/01/geo/wgs84_pos#>
END
	my $correct = {
					method			=> 'SELECT',
					'triples'		=> [
						 bless( [
								  bless( [
										   'FILTER',
										   bless( [
													bless( [
															 'URI',
															 'sparql:regex'
														   ], 'RDF::Query::Node::Resource' ),
													bless( [
															 'homepage'
														   ], 'RDF::Query::Node::Variable' ),
													bless( [
															 'kasei'
														   ], 'RDF::Query::Node::Literal' )
												  ], 'RDF::Query::Expression::Function' ),
										   bless( [
													bless( [
															 bless( [
																	  'person'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  'URI',
																	  'http://xmlns.com/foaf/0.1/name'
																	], 'RDF::Query::Node::Resource' ),
															 bless( [
																	  'Gregory Todd Williams'
																	], 'RDF::Query::Node::Literal' )
														   ], 'RDF::Query::Algebra::Triple' ),
													bless( [
															 bless( [
																	  'person'
																	], 'RDF::Query::Node::Variable' ),
															 bless( [
																	  'URI',
																	  'http://xmlns.com/foaf/0.1/homepage'
																	], 'RDF::Query::Node::Resource' ),
															 bless( [
																	  'homepage'
																	], 'RDF::Query::Node::Variable' )
														   ], 'RDF::Query::Algebra::Triple' )
												  ], 'RDF::Query::Algebra::GroupGraphPattern' )
										 ], 'RDF::Query::Algebra::Filter' ),
								  [
									bless( [
											 'person'
										   ], 'RDF::Query::Node::Variable' ),
									bless( [
											 'homepage'
										   ], 'RDF::Query::Node::Variable' )
								  ]
								], 'RDF::Query::Algebra::Project' )
					   ],
					'namespaces'	=> {'foaf' => 'http://xmlns.com/foaf/0.1/','rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#','geo' => 'http://www.w3.org/2003/01/geo/wgs84_pos#','dcterms' => 'http://purl.org/dc/terms/'},
					'sources'		=> undef,
					'variables'		=> [bless(['person'], 'RDF::Query::Node::Variable'),bless(['homepage'], 'RDF::Query::Node::Variable')]
				};
	my $parsed	= $parser->parse( $rdql );
	is_deeply( $parsed, $correct, 'regex constraint' );
}
