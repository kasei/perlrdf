use Test::More tests => 73;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(refaddr);

use RDF::Trine qw(variable literal);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Node;
use RDF::Trine::Namespace qw(xsd);

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');
my $a		= RDF::Trine::Node::Blank->new('a');
my $b		= RDF::Trine::Node::Blank->new();
my $l		= RDF::Trine::Node::Literal->new( 'value' );
my $ll		= RDF::Trine::Node::Literal->new( 'value', 'en' );
my $dl		= RDF::Trine::Node::Literal->new( '123', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $dl2		= RDF::Trine::Node::Literal->new( '123', undef, $xsd->integer );
my $dl3		= RDF::Trine::Node::Literal->new( '123', undef, $xsd->decimal );
my $p		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
my $p2		= RDF::Trine::Node::Resource->new('#greg', URI->new('http://kasei.us/about/foaf.xrdf'));
my $name	= RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/name');
my $v		= RDF::Trine::Node::Variable->new('v');
my $k		= RDF::Trine::Node::Resource->new('http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる');
my $k2		= RDF::Trine::Node::Resource->new('/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる', 'http://www.w3.org/');
my $k3		= RDF::Trine::Node::Resource->new('#食べる', 'http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji/食');
my $urn		= RDF::Trine::Node::Resource->new('urn:x-demonstrate:bug');

throws_ok { RDF::Trine::Node::Literal->new('foo', 'en', 'http://dt') } 'RDF::Trine::Error::MethodInvocationError', 'RDF::Trine::Node::Literal::new throws with both langauge and datatype';
throws_ok { RDF::Trine::Node::Blank->new('foo bar') } 'RDF::Trine::Error::SerializationError', 'RDF::Trine::Node::Blank::new throws with a label that includes whitespace';

is( $b->type, 'BLANK', 'blank type' );
is( $l->type, 'LITERAL', 'literal type' );
is( $p->type, 'URI', 'resource type' );

ok( $a->is_node, 'is_node' );
ok( not($a->is_resource), '!is_resource' );
ok( not($p->isa('RDF::Trine::Node::Blank')), '!is_blank' );
ok( not($p->is_variable), '!is_variable' );

ok( $a->equal( $a ), 'blank equal' );
ok( not($a->equal( $b )), 'blank not-equal' );
ok( not($a->equal( $name )), 'blank-resource not-equal' );

ok( $name->equal( $foaf->name ), 'resource equal' );
ok( not($name->equal( $p )), 'resource not-equal' );

ok( not($l->equal(0)), 'literal not-equal non-blessed' );
ok( not($l->equal(bless({},'Foo'))), 'literal not-equal non-recognized blessed' );
ok( not($l->equal( $p )), 'literal not-equal resource' );
ok( not($ll->equal( $dl )), 'plain and dt literals not-equal' );
ok( $dl->equal( $dl2 ), 'dt literals equal' );
ok( not($dl->equal( $dl3 )), 'different dt literals not-equal' );
ok( not($ll->equal( literal(qw(value en-us)) )), 'language literal not-equal' );
ok( $ll->equal( literal(qw(value en)) ), 'language literal equal' );

ok( not($p->equal( $l )), 'resource not-equal literal' );
ok( $p->equal( $p2 ), 'resource equal resource with URI base' );

ok( not($v->equal(0)), 'variable not-equal non-blessed' );
ok( not($v->equal(bless({},'Foo'))), 'variable not-equal non-recognized blessed' );
ok( not($v->equal($p)), 'variable not-equal resource' );
ok( $v->equal(variable('v')), 'variable equal' );

ok( $k->equal( $k2 ), 'resource equal with base constructor' );

# as_string
is( $a->as_string, '(a)', 'blank as_string' );
is( $l->as_string, '"value"', 'plain literal as_string' );
is( $ll->as_string, '"value"@en', 'language literal as_string' );
is( $dl->as_string, '"123"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal as_string' );
is( $p->as_string, '<http://kasei.us/about/foaf.xrdf#greg>', 'resource as_string' );
is( $k->as_string, '<http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる>', 'unicode literal as_string' );
is( $k3->as_string, '<http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji/食#食べる>', 'resource with unicode base as_string' );

# as_ntriples
is( $a->as_ntriples, '_:a', 'blank as_ntriples' );
is( $l->as_ntriples, '"value"', 'plain literal as_ntriples' );
is( $ll->as_ntriples, '"value"@en', 'language literal as_ntriples' );
is( $dl->as_ntriples, '"123"^^<http://www.w3.org/2001/XMLSchema#integer>', 'datatype literal as_ntriples' );
is( $p->as_ntriples, '<http://kasei.us/about/foaf.xrdf#greg>', 'resource as_ntriples' );
is( $k->as_ntriples, '<http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#\\u98DF\\u3079\\u308B>', 'unicode literal as_ntriples' );
throws_ok { $v->as_ntriples } 'RDF::Trine::Error::UnimplementedError', 'RDF::Trine::Node::Variable::as_ntriples throws';

{
	local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 0;
	my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	is( ref($l), 'RDF::Trine::Node::Literal', 'object is a RDF::Trine::Node::Literal' );
}

SKIP: {
	if (RDF::Trine::Node::Literal::XML->can('new')) {
		lives_ok {
			local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 0;
			my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
		} 'lives on bad xml when ::Node::Literal::XML use is forced off';
		
		throws_ok {
			local($RDF::Trine::Node::Literal::USE_XMLLITERALS)	= 1;
			my $l	= RDF::Trine::Node::Literal->new( '<foo>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
		} 'RDF::Trine::Error', 'throws on bad xml when ::Node::Literal::XML is available';
	} else {
		skip "RDF::Trine::Node::Literal::XML isn't available", 2;
	}
}

{
	my $l		= RDF::Trine::Node::Literal->new( '<foo/>', undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	if (RDF::Trine::Node::Literal::XML->can('new')) {
		isa_ok( $l, 'RDF::Trine::Node::Literal::XML' );
	} else {
		isa_ok( $l, 'RDF::Trine::Node::Literal' );
	}
}

{
	my $u	= RDF::Trine::Node::Resource->new('http://example.com/');
	$u->uri( 'http://example.org/' );
	is( $u->uri, 'http://example.org/', 'resource uri after modification' );
}

{
	my $l	= RDF::Trine::Node::Literal->new('123', undef, $xsd->integer);
	$l->literal_value( '787' );
	is( $l->literal_value, '787', 'literal value after modification' );
}

{
	my ($ns, $l);
	($ns, $l)	= $k->qname;
	is( $l, '食べる', 'unicode qname separation' );
}

{
	my ($ns, $l)	= $urn->qname;
	is($ns, 'urn:x-demonstrate:', 'good URN namespace prefix');
	is($l, 'bug', 'good URN local name');
}

# from_sse
{
	my $n	= RDF::Trine::Node->from_sse( '(a)' );
	isa_ok( $n, 'RDF::Trine::Node::Blank', 'blank from_sse' );
	is( $n->blank_identifier, 'a', 'blank from_sse identifier' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '<iri>' );
	isa_ok( $n, 'RDF::Trine::Node::Resource', 'resource from_sse' );
	is( $n->uri_value, 'iri', 'resource from_sse identifier' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'literal from_sse' );
	is( $n->literal_value, 'value', 'literal from_sse value' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"@en' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'language literal from_sse' );
	is( $n->literal_value, 'value', 'language literal from_sse value' );
	is( $n->literal_value_language, 'en', 'language literal from_sse language' );
}

{
	my $n	= RDF::Trine::Node->from_sse( '"value"^^<dt>' );
	isa_ok( $n, 'RDF::Trine::Node::Literal', 'datatype literal from_sse' );
	is( $n->literal_value, 'value', 'datatype literal from_sse value' );
	is( $n->literal_datatype, 'dt', 'datatype literal from_sse datatype' );
}

{
	my $ctx	= { namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' } };
	my $n	= RDF::Trine::Node->from_sse( 'foaf:name', $ctx );
	isa_ok( $n, 'RDF::Trine::Node::Resource', 'resource from_sse' );
	is( $n->uri_value, 'http://xmlns.com/foaf/0.1/name', 'qname from_sse identifier' );
}

{
	my $n1	= RDF::Trine::Node::Nil->new();
	my $n2	= RDF::Trine::Node::Nil->new();
	is( refaddr($n1), refaddr($n2), 'Nil is a singleton' );
	ok( $n1->equal( $n2 ), 'Nil nodes claim equality' );
	ok( not($n1->equal( $k )), 'Nil node is not equal to non-Nil node' );
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://www.xn--hestebedgrd-58a.dk/');
	my $nt	= $uri->as_ntriples;
	is($nt, "<http://www.hestebedg\\u00E5rd.dk/>", 'latin1-compatible punycode URI properly decoded as an IRI');
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://xn--df-oiy.ws/');
	my $nt	= $uri->as_ntriples;
	is($nt, '<http://\\u272Adf.ws/>', 'high-codepoint punycode URI properly decoded as an IRI');
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://www.xn--orfolkedansere-rqb.dk/#8835/St%C3%A6vne%202013');
	is($uri->uri_value, 'http://www.xn--orfolkedansere-rqb.dk/#8835/St%C3%A6vne%202013', 'punycode URI with percent-escapes');
}

{
	my $uri	= RDF::Trine::Node::Resource->new('http://www.xn--orfolkedansere-rqb.dk/#8835/St%C3%A6vne%202013', 'http://base/');
	is($uri->uri_value, "http://www.xn--orfolkedansere-rqb.dk/#8835/St%C3%A6vne%202013", 'punycode URI with percent-escapes with base');
}
