#!/usr/bin/env perl
use strict;
use Test::More;
use Test::Exception;

use RDF::Query;
use RDF::Query::Parser::SPARQL;

if ($ENV{RDFQUERY_DEV_MYSQL}) {
	plan 'no_plan';
} else {
	plan tests => 34;
}

use_ok( 'RDF::Query::Compiler::SQL' );

my $parser		= new RDF::Query::Parser::SPARQL ();


{
	my $uri	= 'http://xmlns.com/foaf/0.1/name';
	my $node	= RDF::Query::Node::Resource->new( $uri );
	my $hash	= RDF::Query::Compiler::SQL->_mysql_node_hash( $node );
	is( $hash, '14911999128994829034', 'URI hash' );
}

{
	my $node	= RDF::Query::Node::Literal->new( 'kasei' );
	my $hash	= RDF::Query::Compiler::SQL->_mysql_node_hash( $node );
	is( $hash, '12775641923308277283', 'literal hash' );
}

{
	my $hash	= RDF::Query::Compiler::SQL::_mysql_hash( 'LTom Croucher<en>' );
	is( $hash, '14336915341960534814', 'language-typed literal hash' );
}

{
	my $node	= RDF::Query::Node::Literal->new( 'Tom Croucher', 'en' );
	my $hash	= RDF::Query::Compiler::SQL->_mysql_node_hash( $node );
	is( $hash, '14336915341960534814', 'language-typed literal node hash 1' );
}

{
	my $node	= RDF::Query::Node::Literal->new( 'RDF', 'en' );
	my $hash	= RDF::Query::Compiler::SQL->_mysql_node_hash( $node );
	is( $hash, '16625494614570964497', 'language-typed literal node hash 2' );
}



{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{ ?person foaf:name ?name }
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed, 'model' );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements15799945864759145248 s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID)\nWHERE\n\ts2.predicate = 14911999128994829034", "select people and names" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{
					?person foaf:name ?name .
				}
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID)\nWHERE\n\ts2.predicate = 14911999128994829034", "select people and names" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name ?homepage
		WHERE	{
					?person foaf:name ?name ; foaf:homepage ?homepage
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name,\n\ts3.object AS homepage_Node,\n\tljr2.URI AS homepage_URI,\n\tljl2.Value AS homepage_Value,\n\tljl2.Language AS homepage_Language,\n\tljl2.Datatype AS homepage_Datatype,\n\tljb2.Name AS homepage_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID),\n\tStatements s3 LEFT JOIN Resources ljr2 ON (s3.object = ljr2.ID) LEFT JOIN Literals ljl2 ON (s3.object = ljl2.ID) LEFT JOIN Bnodes ljb2 ON (s3.object = ljb2.ID)\nWHERE\n\ts2.predicate = 14911999128994829034 AND\n\ts3.subject = s2.subject AND\n\ts3.predicate = 9768710922987392204", "select people, names, and homepages" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?x ?name
		FROM NAMED <file://data/named_graphs/alice.rdf>
		FROM NAMED <file://data/named_graphs/bob.rdf>
		WHERE {
			GRAPH <foo:bar> { ?x foaf:name ?name }
		}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts3.subject AS x_Node,\n\tljr0.URI AS x_URI,\n\tljl0.Value AS x_Value,\n\tljl0.Language AS x_Language,\n\tljl0.Datatype AS x_Datatype,\n\tljb0.Name AS x_Name,\n\ts3.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s3 LEFT JOIN Resources ljr0 ON (s3.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s3.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s3.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s3.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s3.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s3.object = ljb1.ID)\nWHERE\n\ts3.predicate = 14911999128994829034 AND\n\ts3.context = 2618056589919804847", "select people and names of context-specific graph" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?src ?name
		FROM NAMED <file://data/named_graphs/alice.rdf>
		FROM NAMED <file://data/named_graphs/bob.rdf>
		WHERE {
			GRAPH ?src { ?x foaf:name ?name }
		}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts3.context AS src_Node,\n\tljr0.URI AS src_URI,\n\tljl0.Value AS src_Value,\n\tljl0.Language AS src_Language,\n\tljl0.Datatype AS src_Datatype,\n\tljb0.Name AS src_Name,\n\ts3.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name,\n\tljr2.URI AS x_URI,\n\tljl2.Value AS x_Value,\n\tljl2.Language AS x_Language,\n\tljl2.Datatype AS x_Datatype,\n\tljb2.Name AS x_Name\nFROM\n\tStatements s3 LEFT JOIN Resources ljr0 ON (s3.context = ljr0.ID) LEFT JOIN Literals ljl0 ON (s3.context = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s3.context = ljb0.ID) LEFT JOIN Resources ljr1 ON (s3.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s3.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s3.object = ljb1.ID) LEFT JOIN Resources ljr2 ON (s3.subject = ljr2.ID) LEFT JOIN Literals ljl2 ON (s3.subject = ljl2.ID) LEFT JOIN Bnodes ljb2 ON (s3.subject = ljb2.ID)\nWHERE\n\ts3.predicate = 14911999128994829034", "select context of people and names" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX rss: <http://purl.org/rss/1.0/>
		SELECT ?title
		WHERE {
			<http://kasei.us/> rss:title ?title .
		}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.object AS title_Node,\n\tljr0.URI AS title_URI,\n\tljl0.Value AS title_Value,\n\tljl0.Language AS title_Language,\n\tljl0.Datatype AS title_Datatype,\n\tljb0.Name AS title_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.object = ljb0.ID)\nWHERE\n\ts2.subject = 1083049239652454081 AND\n\ts2.predicate = 17858988500659793691", "select rss:title of uri" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX	dcterms: <http://purl.org/dc/terms/>
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		SELECT	?page
		WHERE	{
					?person foaf:name "Gregory Todd Williams" .
					?person foaf:homepage ?page .
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts3.object AS page_Node,\n\tljr0.URI AS page_URI,\n\tljl0.Value AS page_Value,\n\tljl0.Language AS page_Language,\n\tljl0.Datatype AS page_Datatype,\n\tljb0.Name AS page_Name,\n\tljr1.URI AS person_URI,\n\tljl1.Value AS person_Value,\n\tljl1.Language AS person_Language,\n\tljl1.Datatype AS person_Datatype,\n\tljb1.Name AS person_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr1 ON (s2.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.subject = ljb1.ID),\n\tStatements s3 LEFT JOIN Resources ljr0 ON (s3.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s3.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s3.object = ljb0.ID)\nWHERE\n\ts2.predicate = 14911999128994829034 AND\n\ts2.object = 2782977400239829321 AND\n\ts3.subject = s2.subject AND\n\ts3.predicate = 9768710922987392204", "select homepage of person by name" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?s ?p
		WHERE	{
					?s ?p "RDF"@en .
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS s_Node,\n\tljr0.URI AS s_URI,\n\tljl0.Value AS s_Value,\n\tljl0.Language AS s_Language,\n\tljl0.Datatype AS s_Datatype,\n\tljb0.Name AS s_Name,\n\ts2.predicate AS p_Node,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.predicate = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.predicate = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.predicate = ljb1.ID)\nWHERE\n\ts2.object = 16625494614570964497", "select s,p by language-tagged literal" );
}

{
	RDF::Query::Compiler::SQL->add_function( 'time:now', sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $expr	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my %queryvars	= map { $_->name => 1 } @$parsed_vars;
		return ({}, [], ['NOW()']);
	} );
	
	my $parsed	= $parser->parse(<<'END');
		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX	dcterms: <http://purl.org/dc/terms/>
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
		PREFIX	xsd: <http://www.w3.org/2001/XMLSchema#>
		PREFIX	time: <time:>
		SELECT	?point
		WHERE	{
					?point a geo:Point .
					FILTER( time:now() > "2006-01-01" )
				}
END
	my $sql;
	lives_ok {
		my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
		$sql			= $compiler->compile();
	} 'compile: select with function filter';
	is( $sql, qq(SELECT\n\ts6.subject AS point_Node,\n\tljr0.URI AS point_URI,\n\tljl0.Value AS point_Value,\n\tljl0.Language AS point_Language,\n\tljl0.Datatype AS point_Datatype,\n\tljb0.Name AS point_Name\nFROM\n\tStatements s6 LEFT JOIN Resources ljr0 ON (s6.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s6.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s6.subject = ljb0.ID)\nWHERE\n\tNOW() > '2006-01-01' AND\n\ts6.predicate = 2982895206037061277 AND\n\ts6.object = 11045396790191387947), "sql: select with function filter" );
}

{
	RDF::Query::Compiler::SQL->add_function( 'http://kasei.us/e/ns/geo#distance', sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		my $vars	= $self->{vars};
		my (@from, @where);
		
		my %queryvars	= map { $_->name => 1 } @$parsed_vars;
		
		++$$level; my $sql_a	= $self->expr2sql( $args[0], $level );
		++$$level; my $sql_b	= $self->expr2sql( $args[1], $level );
		++$$level; my $sql_c	= $self->expr2sql( $args[1], $level );
		push(@where, "distance($sql_a, $sql_b, $sql_c)");
		return ($vars, \@from, \@where);
	} );
	
	my $parsed	= $parser->parse(<<'END');
		PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX	dcterms: <http://purl.org/dc/terms/>
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
		PREFIX	xsd: <http://www.w3.org/2001/XMLSchema#>
		SELECT	?image ?point ?lat
		WHERE	{
					?point geo:lat ?lat .
					?image ?pred ?point .
					FILTER( mygeo:distance(?point, +41.849331, -71.392) < "10"^^xsd:integer )
				}
END

	my $sql;
	lives_ok {
		my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
		$sql			= $compiler->compile();
	} 'compile: select images filterd by distance function comparison';
	is( $sql, qq(SELECT\n\ts10.subject AS image_Node,\n\tljr0.URI AS image_URI,\n\tljl0.Value AS image_Value,\n\tljl0.Language AS image_Language,\n\tljl0.Datatype AS image_Datatype,\n\tljb0.Name AS image_Name,\n\ts9.subject AS point_Node,\n\tljr1.URI AS point_URI,\n\tljl1.Value AS point_Value,\n\tljl1.Language AS point_Language,\n\tljl1.Datatype AS point_Datatype,\n\tljb1.Name AS point_Name,\n\ts9.object AS lat_Node,\n\tljr2.URI AS lat_URI,\n\tljl2.Value AS lat_Value,\n\tljl2.Language AS lat_Language,\n\tljl2.Datatype AS lat_Datatype,\n\tljb2.Name AS lat_Name,\n\tljr3.URI AS pred_URI,\n\tljl3.Value AS pred_Value,\n\tljl3.Language AS pred_Language,\n\tljl3.Datatype AS pred_Datatype,\n\tljb3.Name AS pred_Name\nFROM\n\tStatements s9 LEFT JOIN Resources ljr1 ON (s9.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s9.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s9.subject = ljb1.ID) LEFT JOIN Resources ljr2 ON (s9.object = ljr2.ID) LEFT JOIN Literals ljl2 ON (s9.object = ljl2.ID) LEFT JOIN Bnodes ljb2 ON (s9.object = ljb2.ID),\n\tStatements s10 LEFT JOIN Resources ljr0 ON (s10.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s10.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s10.subject = ljb0.ID) LEFT JOIN Resources ljr3 ON (s10.predicate = ljr3.ID) LEFT JOIN Literals ljl3 ON (s10.predicate = ljl3.ID) LEFT JOIN Bnodes ljb3 ON (s10.predicate = ljb3.ID)\nWHERE\n\tdistance(, (0.0 + '+41.849331'), (0.0 + '+41.849331')) < (0 + '10') AND\n\ts9.predicate = 5391429383543785584 AND\n\ts10.object = s9.subject), "sql: select images filterd by distance function comparison" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?name
		WHERE	{
					?p a foaf:Person ; foaf:name ?name .
					FILTER REGEX(?name, "Greg") .
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, qq(SELECT\n\ts5.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s4 LEFT JOIN Resources ljr1 ON (s4.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s4.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s4.subject = ljb1.ID),\n\tStatements s5 LEFT JOIN Resources ljr0 ON (s5.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s5.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s5.object = ljb0.ID)\nWHERE\n\t(ljl0.Value REGEXP 'Greg' OR ljr0.URI REGEXP 'Greg' OR ljb0.Name REGEXP 'Greg') AND\n\ts4.predicate = 2982895206037061277 AND\n\ts4.object = 3652866608875541952 AND\n\ts5.subject = s4.subject AND\n\ts5.predicate = 14911999128994829034), "select people by regex-filtered name" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT	?name
		WHERE	{
					?p a foaf:Person ; foaf:name ?name .
					FILTER REGEX(?name, "Greg") .
				}
		LIMIT 1
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, qq(SELECT DISTINCT\n\ts5.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s4 LEFT JOIN Resources ljr1 ON (s4.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s4.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s4.subject = ljb1.ID),\n\tStatements s5 LEFT JOIN Resources ljr0 ON (s5.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s5.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s5.object = ljb0.ID)\nWHERE\n\t(ljl0.Value REGEXP 'Greg' OR ljr0.URI REGEXP 'Greg' OR ljb0.Name REGEXP 'Greg') AND\n\ts4.predicate = 2982895206037061277 AND\n\ts4.object = 3652866608875541952 AND\n\ts5.subject = s4.subject AND\n\ts5.predicate = 14911999128994829034\nLIMIT 1), "select people by regex-filtered name with DISTINCT and LIMIT" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT	?name
		WHERE	{
					?p a foaf:Person ; foaf:name ?name .
					FILTER( ?name = "Gregory Todd Williams" )
				}
		LIMIT 1
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, qq(SELECT DISTINCT\n\ts7.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s6 LEFT JOIN Resources ljr1 ON (s6.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s6.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s6.subject = ljb1.ID),\n\tStatements s7 LEFT JOIN Resources ljr0 ON (s7.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s7.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s7.object = ljb0.ID)\nWHERE\n\t(SELECT value FROM Literals WHERE  = ID LIMIT 1) = 'Gregory Todd Williams' AND\n\ts6.predicate = 2982895206037061277 AND\n\ts6.object = 3652866608875541952 AND\n\ts7.subject = s6.subject AND\n\ts7.predicate = 14911999128994829034\nLIMIT 1), "select people by Literal name with DISTINCT and LIMIT" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT DISTINCT	?name
		WHERE	{
					?p a foaf:Person ; foaf:name ?name .
					FILTER( ?p = <http://kasei.us/about/foaf.xrdf#greg> )
				}
		LIMIT 1
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, qq(SELECT DISTINCT\n\ts5.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s4 LEFT JOIN Resources ljr1 ON (s4.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s4.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s4.subject = ljb1.ID),\n\tStatements s5 LEFT JOIN Resources ljr0 ON (s5.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s5.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s5.object = ljb0.ID)\nWHERE\n\t = 2954181085641959508 AND\n\ts4.predicate = 2982895206037061277 AND\n\ts4.object = 3652866608875541952 AND\n\ts5.subject = s4.subject AND\n\ts5.predicate = 14911999128994829034\nLIMIT 1), "select people by URI with DISTINCT and LIMIT" );
	
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{
					?person foaf:name ?name .
					FILTER BOUND(?name) .
				}
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts4.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts4.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s4 LEFT JOIN Resources ljr0 ON (s4.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s4.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s4.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s4.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s4.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s4.object = ljb1.ID)\nWHERE\n\t IS NOT NULL AND\n\ts4.predicate = 14911999128994829034", "select people and names with filter BOUND()" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{ ?person foaf:name ?name }
		ORDER BY ?name
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID)\nWHERE\n\ts2.predicate = 14911999128994829034\nORDER BY\n\tname_Value ASC, name_URI ASC, name_Name ASC", "order by names" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{ ?person foaf:name ?name }
		ORDER BY ?name, ?person
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	throws_ok {
		my $sql		= $compiler->compile();
	} 'RDF::Query::Error::CompilationError', 'order by multiple columns throws error';
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		CONSTRUCT { ?person foaf:name ?name }
		WHERE	{ ?person foaf:name ?name }
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed, 'model' );
	throws_ok {
		my $sql		= $compiler->compile();
	} 'RDF::Query::Error::CompilationError', 'non-select throws error';
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX time: <time:>
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{ ?person foaf:name ?name }
		ORDER BY time:now()
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	$compiler->add_function( 'time:now', sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		return ({}, [], ['NOW()']);
	} );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID)\nWHERE\n\ts2.predicate = 14911999128994829034\nORDER BY\n\tNOW() ASC", "order by function (NOW())" );
}

{
	my $parsed	= $parser->parse(<<"END");
		PREFIX func: <func:>
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?person ?name
		WHERE	{ ?person foaf:name ?name }
		ORDER BY func:ascii(?name)
END
	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	$compiler->add_function( 'func:ascii', sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my $expr	= shift;
		
		my $col		= $self->expr2sql( $expr, $level );
		return ({}, [], ["ASCII($col)"]);
	} );
	isa_ok( $compiler, 'RDF::Query::Compiler::SQL' );
	
	my $sql		= $compiler->compile();
	is( $sql, "SELECT\n\ts2.subject AS person_Node,\n\tljr0.URI AS person_URI,\n\tljl0.Value AS person_Value,\n\tljl0.Language AS person_Language,\n\tljl0.Datatype AS person_Datatype,\n\tljb0.Name AS person_Name,\n\ts2.object AS name_Node,\n\tljr1.URI AS name_URI,\n\tljl1.Value AS name_Value,\n\tljl1.Language AS name_Language,\n\tljl1.Datatype AS name_Datatype,\n\tljb1.Name AS name_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.subject = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.subject = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.subject = ljb0.ID) LEFT JOIN Resources ljr1 ON (s2.object = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.object = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.object = ljb1.ID)\nWHERE\n\ts2.predicate = 14911999128994829034\nORDER BY\n\tASCII(ljr1.URI) ASC, ASCII(ljl1.Value) ASC, ASCII(ljl1.Language) ASC", "order by function (ASCII(name))" );
}

	














# if ($ENV{RDFQUERY_DEV_MYSQL}) {
# 	my $model_name	= 'model';
# 	SKIP: {
# 		eval "require Kasei::RDF::Common;";
# 		if ($@) {
# 			warn $@;
# 			exit;
# #			skip "Failed to load Kasei::RDF::Common", 1;
# 		}
# 		
# 		my $dsn		= [ Kasei::Common::mysql_dbi_args() ];
# 		
# 		{
# 			my $model	= DBI->connect( @$dsn );
# 			my $sparql	= <<'END';
# 			SELECT	?s ?p ?o
# 			WHERE	{ ?s ?p ?o }
# 			LIMIT 1
# END
# 			lives_ok {
# 				my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql' );
# 				$query->execute( $model, model => $model_name, require_sql => 1 );
# 			} 's-p-o without pre-bound vars';
# 		}
# 		
# 		{
# 			Kasei::RDF::Common->import('mysql_model');
# 			my @myargs	= Kasei::Common::mysql_upd();
# 			my $model	= mysql_model( $model_name, @myargs[ 2, 0, 1 ] );
# 			
# 			{
# 				my $sparql	= <<'END';
# 				SELECT	?s ?p ?o
# 				WHERE	{ ?s ?p ?o }
# 				LIMIT 1
# END
# 				lives_ok {
# 					my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql' );
# 					$query->execute( $model, dsn => $dsn, model => $model_name, require_sql => 1 );
# 				} 's-p-o without pre-bound vars';
# 				
# 				throws_ok {
# 					my $query	= new RDF::Query ( $sparql, undef, undef, 'sparql' );
# 					$query->execute( $model, dsn => $dsn, model => $model_name, require_sql => 1, bind => { p => 1 } );
# 				} 'RDF::Query::Error::CompilationError', 's-p-o without pre-bound vars: forced sql compilation (expected) failure';
# 			}
# 			
# 			{
# 				my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 				PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
# 				SELECT	?image ?point ?lat
# 				WHERE	{
# 							?point geo:lat ?lat .
# 							?image ?pred ?point .
# 							FILTER(	geo:distance(?point) ) .
# 						}
# END
# 				throws_ok {
# 					$query->execute( $model, dsn => $dsn, model => $model_name, require_sql => 1 );
# 				} 'RDF::Query::Error::CompilationError', 'forced sql compilation (expected) failure';
# 			}
# 			
# 			{
# 				print "# FILTER rage test\n";
# 				my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
# 				PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
# 				SELECT	?image ?point ?lat
# 				WHERE	{
# 							?image a foaf:Image ; ?pred ?point .
# 							?point geo:lat ?lat .
# 							FILTER(
# 								(?pred = <http://purl.org/dc/terms/spatial> || ?pred = <http://xmlns.com/foaf/0.1/based_near>)
# 								&&	?lat > 52
# 								&&	?lat < 53
# 							) .
# 						}
# END
# 				my $stream	= $query->execute( $model, dsn => $dsn, model => $model_name );
# 	
# 				my $count;
# 				while (my $row = $stream->()) {
# 					my ($image, $point, $lat)	= @{ $row };
# 					ok( $image->isa('RDF::Trine::Node::Resource'), 'image is resource');
# 					my $latv	= ($lat) ? $lat->literal_value : undef;
# 					cmp_ok( $latv, '>', 52, 'lat: ' . $latv );
# 					cmp_ok( $latv, '<', 53, 'lat: ' . $latv );
# 					$count++;
# 				}
# 			}
# 			
# 			{
# 				print "# lots of points!\n";
# 				my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 					PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
# 					PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
# 					SELECT	?name
# 					WHERE	{
# 								?point a geo:Point; foaf:name ?name .
# 							}
# END
# 				my $stream	= $query->execute( $model, dsn => $dsn, model => $model_name );
# 				isa_ok( $stream, 'CODE', 'stream' );
# 				my $count;
# 				while (my $row = $stream->()) {
# 					my ($node)	= @{ $row };
# 					my $name	= $node->as_string;
# 					ok( $name, $name );
# 				} continue { last if ++$count >= 100 };
# 			}
# 			
# 			{
# 				print "# foaf:Person ORDER BY name\n";
# 				my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 					PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
# 					PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
# 					SELECT	DISTINCT ?p ?name
# 					WHERE	{
# 								?p a foaf:Person; foaf:name ?name
# 							}
# 					ORDER BY ?name
# END
# 				my $stream	= $query->execute( $model, dsn => $dsn, model => $model_name );
# 				isa_ok( $stream, 'CODE', 'stream' );
# 				my ($count, $last);
# 				while (my $row = $stream->()) {
# 					my ($p, $node)	= @{ $row };
# 					my $name	= $node->as_string;
# 					if (defined($last)) {
# 						cmp_ok( $name, 'ge', $last, "In order: $name (" . $p->as_string . ")" );
# 					} else {
# 						ok( $name, "$name (" . $p->as_string . ")" );
# 					}
# 					$last	= $name;
# 				} continue { last if ++$count >= 200 };
# 			}
# 			
# 			{
# 				print "# geo:Point ORDER BY longitude\n";
# 				my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
# 					PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
# 					PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
# 					PREFIX	xsd: <http://www.w3.org/2001/XMLSchema#>
# 					SELECT	DISTINCT ?name ?lat ?lon
# 					WHERE	{
# 								?point a geo:Point; foaf:name ?name; geo:lat ?lat; geo:long ?lon
# 							}
# 					ORDER BY DESC( xsd:decimal(?lon) )
# END
# 				my $stream	= $query->execute( $model, dsn => $dsn, model => $model_name );
# 				isa_ok( $stream, 'CODE', 'stream' );
# 				my ($count, $last);
# 				while (my $row = $stream->()) {
# 					my ($node, $lat, $long)	= @{ $row };
# 					my $name	= $node->as_string;
# 					if (defined($last)) {
# 						cmp_ok( $long->as_string, '<=', $last, "In order: $name (" . $long->as_string . ")" );
# 					} else {
# 						ok( $name, "$name (" . $long->as_string . ")" );
# 					}
# 					$last	= $long->as_string;
# 				} continue { last if ++$count >= 200 };
# 			}
# 		}
# 	}
# }



# if ($ENV{RDFQUERY_DEV_POSTGRESQL}) {
# 	eval "require Kasei::RDF::Common;";
# 	$ENV{'POSTGRESQL_MODEL'}	= 'model';
# 	$ENV{'POSTGRESQL_DATABASE'}	= 'greg';
# 	$ENV{'POSTGRESQL_PASSWORD'}	= 'password';
# 	
# 	Kasei::RDF::Common->import('postgresql_model');
# 	my $dbh		= postgresql_model();
# 	warn $dbh;
# 	
# 	my @myargs	= Kasei::Common::postgresql_upd();
# 	my $model	= postgresql_model( 'db1', @myargs[ 2, 0, 1 ] );
# 	my $dsn		= [ Kasei::Common::postgresql_dbi_args() ];
# 	
# 	warn $model;
# 	warn Dumper($dsn);
# 
# 
# }



__END__
{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?name
		WHERE	{
					?p a foaf:Person .
					?p foaf:name ?name .
					FILTER( ?p = _:r1101876070r10 )
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	is( $sql, qq(SELECT\n\ts2.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr1 ON (s2.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.subject = ljb1.ID),\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.object = ljb0.ID)\nWHERE\n\ts2.predicate = 2982895206037061277 AND\n\ts2.object = 3652866608875541952 AND\n\ts2.subject = s2.subject AND\n\ts2.predicate = 14911999128994829034 AND\n\ts2.subject = 4025741532186680712), "select people by BNode" );
}

{
	my $parsed	= $parser->parse(<<'END');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		SELECT	?name
		WHERE	{
					?p a foaf:Person ; foaf:name ?name .
					FILTER( ?p = [] )
				}
END

	my $compiler	= RDF::Query::Compiler::SQL->new( $parsed );
	my $sql		= $compiler->compile();
	$sql		=~ s/(s2.subject\s*=\s*)\d+/$1XXX/;
	is( $sql, qq(SELECT\n\ts2.object AS name_Node,\n\tljr0.URI AS name_URI,\n\tljl0.Value AS name_Value,\n\tljl0.Language AS name_Language,\n\tljl0.Datatype AS name_Datatype,\n\tljb0.Name AS name_Name,\n\tljr1.URI AS p_URI,\n\tljl1.Value AS p_Value,\n\tljl1.Language AS p_Language,\n\tljl1.Datatype AS p_Datatype,\n\tljb1.Name AS p_Name\nFROM\n\tStatements s2 LEFT JOIN Resources ljr1 ON (s2.subject = ljr1.ID) LEFT JOIN Literals ljl1 ON (s2.subject = ljl1.ID) LEFT JOIN Bnodes ljb1 ON (s2.subject = ljb1.ID),\n\tStatements s2 LEFT JOIN Resources ljr0 ON (s2.object = ljr0.ID) LEFT JOIN Literals ljl0 ON (s2.object = ljl0.ID) LEFT JOIN Bnodes ljb0 ON (s2.object = ljb0.ID)\nWHERE\n\ts2.predicate = 2982895206037061277 AND\n\ts2.object = 3652866608875541952 AND\n\ts2.subject = s2.subject AND\n\ts2.predicate = 14911999128994829034 AND\n\ts2.subject = XXX), "select people by BNode" );
}


