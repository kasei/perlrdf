use Test::More tests => 5;

use strict;
use warnings;
no warnings 'redefine';

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
	my $store	= RDF::Trine::Store::DBI->new('temp');
	my $sql		= $store->_sql_for_pattern( $triple );
	sql_like( $sql, qr'SELECT s0[.]object AS title_Node, ljr0[.]URI AS title_URI, ljl0[.]Value AS title_Value, ljl0[.]Language AS title_Language, ljl0[.]Datatype AS title_Datatype, ljb0[.]Name AS title_Name, s0[.]Context AS sql_ctx_1_Node, ljr1[.]URI AS sql_ctx_1_URI, ljl1[.]Value AS sql_ctx_1_Value, ljl1[.]Language AS sql_ctx_1_Language, ljl1[.]Datatype AS sql_ctx_1_Datatype, ljb1[.]Name AS sql_ctx_1_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0[.]object = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0[.]object = ljb0[.]ID[)] LEFT JOIN Resources ljr1 ON [(]s0[.]Context = ljr1[.]ID[)] LEFT JOIN Literals ljl1 ON [(]s0[.]Context = ljl1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]Context = ljb1[.]ID[)] WHERE s0[.]subject = 2882409734267140843 AND s0[.]predicate = 16668832798855018521$', 'triple to sql' );
}

{
	my $triple1	= RDF::Trine::Statement->new($s, $title, $v1);
	my $triple2	= RDF::Trine::Statement->new($s, $desc, $v2);
	my $bgp		= RDF::Trine::Pattern->new( $triple1, $triple2 );
	my $store	= RDF::Trine::Store::DBI->new('temp');
	my $sql		= $store->_sql_for_pattern( $bgp );
	sql_like( $sql, qr'SELECT s1[.]Context AS sql_ctx_2_Node, ljr0[.]URI AS sql_ctx_2_URI, ljl0[.]Value AS sql_ctx_2_Value, ljl0[.]Language AS sql_ctx_2_Language, ljl0[.]Datatype AS sql_ctx_2_Datatype, ljb0[.]Name AS sql_ctx_2_Name, s0[.]object AS title_Node, ljr1[.]URI AS title_URI, ljl1[.]Value AS title_Value, ljl1[.]Language AS title_Language, ljl1[.]Datatype AS title_Datatype, ljb1[.]Name AS title_Name, s1[.]object AS description_Node, ljr2[.]URI AS description_URI, ljl2[.]Value AS description_Value, ljl2[.]Language AS description_Language, ljl2[.]Datatype AS description_Datatype, ljb2[.]Name AS description_Name, s0[.]Context AS sql_ctx_1_Node, ljr3[.]URI AS sql_ctx_1_URI, ljl3[.]Value AS sql_ctx_1_Value, ljl3[.]Language AS sql_ctx_1_Language, ljl3[.]Datatype AS sql_ctx_1_Datatype, ljb3[.]Name AS sql_ctx_1_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr1 ON [(]s0[.]object = ljr1[.]ID[)] LEFT JOIN Literals ljl1 ON [(]s0[.]object = ljl1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]object = ljb1[.]ID[)] LEFT JOIN Resources ljr3 ON [(]s0[.]Context = ljr3[.]ID[)] LEFT JOIN Literals ljl3 ON [(]s0[.]Context = ljl3[.]ID[)] LEFT JOIN Bnodes ljb3 ON [(]s0[.]Context = ljb3[.]ID[)], Statements14109427105860845629 s1 LEFT JOIN Resources ljr0 ON [(]s1[.]Context = ljr0[.]ID[)] LEFT JOIN Literals ljl0 ON [(]s1[.]Context = ljl0[.]ID[)] LEFT JOIN Bnodes ljb0 ON [(]s1[.]Context = ljb0[.]ID[)] LEFT JOIN Resources ljr2 ON [(]s1[.]object = ljr2[.]ID[)] LEFT JOIN Literals ljl2 ON [(]s1[.]object = ljl2[.]ID[)] LEFT JOIN Bnodes ljb2 ON [(]s1[.]object = ljb2[.]ID[)] WHERE s0[.]subject = 2882409734267140843 AND s0[.]predicate = 16668832798855018521 AND s1[.]subject = 2882409734267140843 AND s1[.]predicate = 14986803616804843731$', 'bgp to sql' );
}

{
	my $triple	= RDF::Trine::Statement->new($s, $title, $v1);
	my $store	= RDF::Trine::Store::DBI->new('temp');
	my $ctx		= RDF::Trine::Node::Resource->new( 'http://example.com/' );
	my $sql		= $store->_sql_for_pattern( $triple, $ctx );
	sql_like( $sql, qr'SELECT s0.object AS title_Node, ljr0.URI AS title_URI, ljl0.Value AS title_Value, ljl0.Language AS title_Language, ljl0.Datatype AS title_Datatype, ljb0.Name AS title_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0.object = ljr0.ID[)] LEFT JOIN Literals ljl0 ON [(]s0.object = ljl0.ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0.object = ljb0.ID[)] WHERE s0.subject = 2882409734267140843 AND s0.predicate = 16668832798855018521 AND s0.Context = 2882409734267140843$', 'triple with context to sql' );
}

{
	my $triple	= RDF::Trine::Statement->new($v1, $v1, $v1);
	my $store	= RDF::Trine::Store::DBI->new('temp');
	my $ctx		= RDF::Trine::Node::Resource->new( 'http://example.com/' );
	my $sql		= $store->_sql_for_pattern( $triple, $ctx );
	sql_like( $sql, qr'SELECT s0.subject AS title_Node, ljr0.URI AS title_URI FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0.subject = ljr0.ID[)] WHERE s0.predicate = s0.subject AND s0.object = s0.subject AND s0.Context = 2882409734267140843$', 'triple with context to sql' );
}

SKIP: {
	eval "use RDF::Query;";
	if ($@) {
		skip("RDF::Query can't be loaded", 1);
	} else {
		my $s		= RDF::Query::Node::Resource->new('http://example/x1');
		my $p		= RDF::Query::Node::Resource->new('http://purl.org/dc/elements/1.1/title');
		my $v		= RDF::Query::Node::Variable->new('v');
		my $l		= RDF::Query::Node::Literal->new('literal');
		
		{
			my $triple	= RDF::Query::Algebra::Triple->new($s, $p, $v);
			my $expr	= RDF::Query::Algebra::Expr::Function->new( 'sparql:isliteral', $v );
			my $filter	= RDF::Query::Algebra::Filter->new( $expr, $triple );
			my $store	= RDF::Trine::Store::DBI->new('temp');
			my $sql		= $store->_sql_for_pattern( $filter );
			sql_like( $sql, qr'SELECT s0[.]object AS v_Node, ljl0[.]Value AS v_Value, ljl0[.]Language AS v_Language, ljl0[.]Datatype AS v_Datatype, s0[.]Context AS sql_ctx_1_Node, ljr1[.]URI AS sql_ctx_1_URI, ljl1[.]Value AS sql_ctx_1_Value, ljl1[.]Language AS sql_ctx_1_Language, ljl1[.]Datatype AS sql_ctx_1_Datatype, ljb1[.]Name AS sql_ctx_1_Name FROM Statements14109427105860845629 s0 LEFT JOIN Literals ljl0 ON [(]s0[.]object = ljl0[.]ID[)] LEFT JOIN Resources ljr1 ON [(]s0[.]Context = ljr1[.]ID[)] LEFT JOIN Literals ljl1 ON [(]s0[.]Context = ljl1[.]ID[)] LEFT JOIN Bnodes ljb1 ON [(]s0[.]Context = ljb1[.]ID[)] WHERE s0[.]subject = 17375543198360951945 AND s0[.]predicate = 16668832798855018521$', 'triple with isliteral(?node) filter' );
		}
	}
}



sub sql_like {
	my $sql		= shift;
	my $pat		= shift;
	my $name	= shift;
	$sql	=~ s/\s+/ /g;
	like( $sql, $pat, $name );
}
