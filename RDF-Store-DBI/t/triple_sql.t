use Test::More tests => 3;

use strict;
use warnings;

use RDF::Query::Node;
use RDF::Query::Algebra;
use RDF::Store::DBI;
use XML::Namespace;

my $dc		= XML::Namespace->new('http://purl.org/dc/elements/1.1/');
my $foaf	= XML::Namespace->new('http://xmlns.com/foaf/0.1/');

my $s		= RDF::Query::Node::Resource->new( 'http://example.com/' );
my $title	= RDF::Query::Node::Resource->new( $dc->title );
my $desc	= RDF::Query::Node::Resource->new( $dc->description );
my $v1		= RDF::Query::Node::Variable->new( 'title' );
my $v2		= RDF::Query::Node::Variable->new( 'description' );

{
	my $triple	= RDF::Query::Algebra::Triple->new($s, $title, $v1);
	my $store	= RDF::Store::DBI->new('temp');
	my $sql		= $store->_sql_for_pattern( $triple );
	sql_like( $sql, qr'SELECT s0.object AS title_Node, ljr0.URI AS title_URI, ljl0.Value AS title_Value, ljl0.Language AS title_Language, ljl0.Datatype AS title_Datatype, ljb0.Name AS title_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0.object = ljr0.ID[)] LEFT JOIN Literals ljl0 ON [(]s0.object = ljl0.ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0.object = ljb0.ID[)] WHERE s0.subject = 2882409734267140843 AND s0.predicate = 16668832798855018521$', 'triple to sql' );
}

{
	my $triple1	= RDF::Query::Algebra::Triple->new($s, $title, $v1);
	my $triple2	= RDF::Query::Algebra::Triple->new($s, $desc, $v2);
	my $bgp		= RDF::Query::Algebra::BasicGraphPattern->new( $triple1, $triple2 );
	my $store	= RDF::Store::DBI->new('temp');
	my $sql		= $store->_sql_for_pattern( $bgp );
	sql_like( $sql, qr'SELECT s0.object AS title_Node, ljr0.URI AS title_URI, ljl0.Value AS title_Value, ljl0.Language AS title_Language, ljl0.Datatype AS title_Datatype, ljb0.Name AS title_Name, s1.object AS description_Node, ljr1.URI AS description_URI, ljl1.Value AS description_Value, ljl1.Language AS description_Language, ljl1.Datatype AS description_Datatype, ljb1.Name AS description_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0.object = ljr0.ID[)] LEFT JOIN Literals ljl0 ON [(]s0.object = ljl0.ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0.object = ljb0.ID[)], Statements14109427105860845629 s1 LEFT JOIN Resources ljr1 ON [(]s1.object = ljr1.ID[)] LEFT JOIN Literals ljl1 ON [(]s1.object = ljl1.ID[)] LEFT JOIN Bnodes ljb1 ON [(]s1.object = ljb1.ID[)] WHERE s0.subject = 2882409734267140843 AND s0.predicate = 16668832798855018521 AND s1.subject = 2882409734267140843 AND s1.predicate = 14986803616804843731$', 'bgp to sql' );
}

{
	my $triple	= RDF::Query::Algebra::Triple->new($s, $title, $v1);
	my $store	= RDF::Store::DBI->new('temp');
	my $ctx		= RDF::Query::Node::Resource->new( 'http://example.com/' );
	my $sql		= $store->_sql_for_pattern( $triple, $ctx );
	sql_like( $sql, qr'SELECT s0.object AS title_Node, ljr0.URI AS title_URI, ljl0.Value AS title_Value, ljl0.Language AS title_Language, ljl0.Datatype AS title_Datatype, ljb0.Name AS title_Name FROM Statements14109427105860845629 s0 LEFT JOIN Resources ljr0 ON [(]s0.object = ljr0.ID[)] LEFT JOIN Literals ljl0 ON [(]s0.object = ljl0.ID[)] LEFT JOIN Bnodes ljb0 ON [(]s0.object = ljb0.ID[)] WHERE s0.subject = 2882409734267140843 AND s0.predicate = 16668832798855018521 AND s0.Context = 2882409734267140843$', 'triple with context to sql' );
}



sub sql_like {
	my $sql		= shift;
	my $pat		= shift;
	my $name	= shift;
	$sql	=~ s/\s+/ /g;
	like( $sql, $pat, $name );
}
