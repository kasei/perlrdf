use Test::More tests => 12;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use XML::Namespace;

my $dc		= XML::Namespace->new('http://purl.org/dc/elements/1.1/');
my $foaf	= XML::Namespace->new('http://xmlns.com/foaf/0.1/');

my $s		= RDF::Trine::Node::Resource->new( 'http://example.com/' );
my $title	= RDF::Trine::Node::Resource->new( $dc->title );
my $desc	= RDF::Trine::Node::Resource->new( $dc->description );
my $v1		= RDF::Trine::Node::Variable->new( 'title' );
my $v2		= RDF::Trine::Node::Variable->new( 'description' );

{
	my $triple	= RDF::Trine::Statement->new($s, $title, $v1);
	my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
	my $sql		= $store->_sql_for_pattern( $triple );
	sql_like( $sql, qr'SELECT s0[.]object AS title_Node, ljr0[.]URI AS title_URI, ljl0[.]Value AS title_Value, ljl0[.]Language AS title_Language, ljl0[.]Datatype AS title_Datatype, ljb0[.]Name AS title_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 2882409734267140843 AND s0[.]predicate = 7445460762000242713', 'triple to sql' );
}

{
	my $triple1	= RDF::Trine::Statement->new($s, $title, $v1);
	my $triple2	= RDF::Trine::Statement->new($s, $desc, $v2);
	my $bgp		= RDF::Trine::Pattern->new( $triple1, $triple2 );
	my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
	my $sql		= $store->_sql_for_pattern( $bgp );
	sql_like( $sql, qr'SELECT s1[.]object AS description_Node, ljr0[.]URI AS description_URI, ljl0[.]Value AS description_Value, ljl0[.]Language AS description_Language, ljl0[.]Datatype AS description_Datatype, ljb0[.]Name AS description_Name, s0[.]object AS title_Node, ljr1[.]URI AS title_URI, ljl1[.]Value AS title_Value, ljl1[.]Language AS title_Language, ljl1[.]Datatype AS title_Datatype, ljb1[.]Name AS title_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr1 ON [(]s0[.]object = ljr1[.]ID[)] LEFT JOIN Literals ljl1 ON [(]s0[.]object = ljl1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]object = ljb1[.]ID[)], Statements4886055069006069821 s1 LEFT JOIN Resources ljr0 ON [(]s1[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s1[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s1[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 2882409734267140843 AND s0[.]predicate = 7445460762000242713 AND s1[.]subject = 2882409734267140843 AND s1[.]predicate = 5763431579950067923$', 'bgp to sql' );
}

{
	my $triple	= RDF::Trine::Statement->new($s, $title, $v1);
	my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
	my $ctx		= RDF::Trine::Node::Resource->new( 'http://example.com/' );
	my $sql		= $store->_sql_for_pattern( $triple, $ctx );
	sql_like( $sql, qr'SELECT s0.object AS title_Node, ljr0.URI AS title_URI, ljl0.Value AS title_Value, ljl0.Language AS title_Language, ljl0.Datatype AS title_Datatype, ljb0.Name AS title_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0.object = ljr0.ID[)] LEFT JOIN Literals ljl0 ON [(]s0.object = ljl0.ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0.object = ljb0.ID[)] WHERE s0.subject = 2882409734267140843 AND s0.predicate = 7445460762000242713 AND s0.Context = 2882409734267140843$', 'triple with context to sql (1)' );
}

{
	my $triple	= RDF::Trine::Statement->new($v1, $v1, $v1);
	my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
	my $ctx		= RDF::Trine::Node::Resource->new( 'http://example.com/' );
	my $sql		= $store->_sql_for_pattern( $triple, $ctx );
	sql_like( $sql, qr'SELECT s0.subject AS title_Node, ljr0.URI AS title_URI FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0.subject = ljr0.ID[)] WHERE s0.predicate = s0.subject AND s0.object = s0.subject AND s0.Context = 2882409734267140843 AND [(]ljr0[.]URI IS NOT NULL[)]$', 'triple with context to sql (2)' );
}

eval "use RDF::Query 2.000; use RDF::Query::Expression;";
my $RDF_QUERY_LOADED	= ($@) ? 0 : 1;

SKIP: {
	if (not($RDF_QUERY_LOADED)) {
		skip("RDF::Query can't be loaded", 8);
	} else {
		my $s		= RDF::Query::Node::Resource->new('http://example/x1');
		my $p		= RDF::Query::Node::Resource->new('http://purl.org/dc/elements/1.1/title');
		my $v		= RDF::Query::Node::Variable->new('v');
		my $x		= RDF::Query::Node::Variable->new('x');
		my $l		= RDF::Query::Node::Literal->new('literal');
		
		{
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $expr	= RDF::Query::Expression::Function->new( 'sparql:isliteral', $v );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $triple );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype FROM Statements4886055069006069821 s0 LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] WHERE s0[.]subject = 8152171161506176137 AND s0[.]predicate = 7445460762000242713 AND [(]ljl0[.]Value IS NOT NULL[)]$', 'triple with isliteral(?node) filter' );
		}
		
		{
			my $s		= RDF::Query::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
			my $p1		= RDF::Query::Node::Resource->new('http://xmlns.com/foaf/0.1/made');
			my $p2		= RDF::Query::Node::Resource->new('http://xmlns.com/foaf/0.1/img');
			my $v		= RDF::Query::Node::Variable->new('v');
			my $triple1	= RDF::Query::Algebra::Triple->new($s, $p1, $v);
			my $triple2	= RDF::Query::Algebra::Triple->new($s, $p2, $v);
			my $union	= RDF::Query::Algebra::Union->new( $triple1, $triple2 );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('endpoint');
			my $sql		= $store->_sql_for_pattern( $union );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4926934303433647533 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 2954181085641959508 AND s0[.]predicate = 9044939471181188842 UNION SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4926934303433647533 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 2954181085641959508 AND s0[.]predicate = 7452795881103254944$', 'UNION pattern with two triples' );
		}
		
		{
			my $p1		= RDF::Query::Node::Resource->new('http://xmlns.com/foaf/0.1/made');
			my $p2		= RDF::Query::Node::Resource->new('http://xmlns.com/foaf/0.1/img');
			my $triple1	= RDF::Query::Algebra::Triple->new($v, $p1, $x);
			my $triple2	= RDF::Query::Algebra::Triple->new($x, $p2, $v);
			my $union	= RDF::Query::Algebra::Union->new( $triple1, $triple2 );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('endpoint');
			my $sql		= $store->_sql_for_pattern( $union );
			sql_like( $sql, qr'SELECT s0[.]subject AS v_Node, ljr0[.]URI AS v_URI, ljb0[.]Name AS v_Name, s0[.]object AS x_Node, ljr1[.]URI AS x_URI, ljl1[.]Value AS x_Value, ljl1[.]Language AS x_Language, ljl1[.]Datatype AS x_Datatype, ljb1[.]Name AS x_Name FROM Statements4926934303433647533 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]subject = ljr0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]subject = ljb0[.]ID[)] LEFT JOIN Resources ljr1 ON [(]s0[.]object = ljr1[.]ID[)] LEFT JOIN Literals ljl1 ON [(]s0[.]object = ljl1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]object = ljb1[.]ID[)] WHERE s0[.]predicate = 9044939471181188842 AND [(]ljr0[.]URI IS NOT NULL OR ljb0[.]Name IS NOT NULL[)] UNION SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name, s0[.]subject AS x_Node, ljr1[.]URI AS x_URI, ljb1[.]Name AS x_Name FROM Statements4926934303433647533 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] LEFT JOIN Resources ljr1 ON [(]s0[.]subject = ljr1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]subject = ljb1[.]ID[)] WHERE s0[.]predicate = 7452795881103254944 AND [(]ljr1[.]URI IS NOT NULL OR ljb1[.]Name IS NOT NULL[)]$', 'UNION pattern with reversed variable orderings' );
		}
		
		{
			my $lit		= RDF::Query::Node::Literal->new('Jan');
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $expr	= RDF::Query::Expression::Binary->new( '==', $v, $lit );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $triple );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 8152171161506176137 AND s0[.]predicate = 7445460762000242713 AND s0[.]object = 3959637603443298718$', 'triple with equality test filter' );
		}
		
		{
			my $lit		= RDF::Query::Node::Literal->new('Jan');
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $bgp		= RDF::Query::Algebra::BasicGraphPattern->new( $triple );
			my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( $bgp );
			my $expr	= RDF::Query::Expression::Binary->new( '==', $v, $lit );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $ggp );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 8152171161506176137 AND s0[.]predicate = 7445460762000242713 AND s0[.]object = 3959637603443298718$', 'GGP with equality test filter' );
		}
		
		{
			my $jan		= RDF::Query::Node::Literal->new('Jan');
			my $feb		= RDF::Query::Node::Literal->new('Feb');
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $expr1	= RDF::Query::Expression::Binary->new( '==', $v, $jan );
			my $expr2	= RDF::Query::Expression::Binary->new( '==', $v, $feb );
			my $logor	= RDF::Query::Node::Resource->new('sparql:logical-or');
			my $expr	= RDF::Query::Expression::Function->new( $logor, $expr1, $expr2 );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $triple );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 8152171161506176137 AND s0[.]predicate = 7445460762000242713 AND [(]s0[.]object = 3959637603443298718 OR s0[.]object = 6163367387132455909[)]$', 'triple with equality test disjunction filter' );
		}
		
		{
			my $jan		= RDF::Query::Node::Literal->new('Jan');
			my $feb		= RDF::Query::Node::Literal->new('Feb');
			my $mar		= RDF::Query::Node::Literal->new('Mar');
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $expr1	= RDF::Query::Expression::Binary->new( '==', $v, $jan );
			my $expr2	= RDF::Query::Expression::Binary->new( '==', $v, $feb );
			my $expr3	= RDF::Query::Expression::Binary->new( '==', $v, $mar );
			my $logor	= RDF::Query::Node::Resource->new('sparql:logical-or');
			my $expr4	= RDF::Query::Expression::Function->new( $logor, $expr1, $expr2 );
			my $expr	= RDF::Query::Expression::Function->new( $logor, $expr4, $expr3 );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $triple );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljr0[.]URI AS v_URI, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, ljb0[.]Name AS v_Name FROM Statements4886055069006069821 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] WHERE s0[.]subject = 8152171161506176137 AND s0[.]predicate = 7445460762000242713 AND [(]s0[.]object = 3959637603443298718 OR s0[.]object = 6163367387132455909 OR s0[.]object = 6604099646270077689[)]$', 'triple with equality test deep-disjunction filter' );
		}
		
		throws_ok {
			my $triple1	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $triple2	= RDF::Query::Algebra::Triple->new($s, $p, $x);
			my $union	= RDF::Query::Algebra::Union->new( $triple1, $triple2 );
			my $store	= RDF::Trine::Store::DBI::SQLite->new('endpoint');
			my $sql		= $store->_sql_for_pattern( $union );
			warn $sql;
		} 'RDF::Trine::Error::CompilationError', 'UNION block with different referenced variables throws error';
	}
}



sub sql_like {
	my $sql		= shift;
	my $pat		= shift;
	my $name	= shift;
	$sql	=~ s/\s+/ /g;
	like( $sql, $pat, $name );
}
