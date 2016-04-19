#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 210;
use Test::Exception;
use Scalar::Util qw(reftype blessed);

use RDF::Query;
use RDF::Query::Node;
use RDF::Query::Algebra;
use RDF::Query::Functions;

my $bz		= RDF::Query::Node::Blank->new( 'z' );
my $bb		= RDF::Query::Node::Blank->new( 'b' );
my $ba		= RDF::Query::Node::Blank->new( 'a' );

my $li		= RDF::Query::Node::Literal->new( 'i' );
my $lb		= RDF::Query::Node::Literal->new( 'b' );
my $la		= RDF::Query::Node::Literal->new( 'a' );
my $lalpha	= RDF::Query::Node::Literal->new( 'abcdefg' );
my $lALPHA	= RDF::Query::Node::Literal->new( 'ABCDEFG' );
my $lal		= RDF::Query::Node::Literal->new( 'a', 'en' );
my $l1		= RDF::Query::Node::Literal->new( '1' );
my $l2d		= RDF::Query::Node::Literal->new( '2.0', undef, 'http://www.w3.org/2001/XMLSchema#float' );
my $l1d		= RDF::Query::Node::Literal->new( '1', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l4d		= RDF::Query::Node::Literal->new( '-4', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l5d		= RDF::Query::Node::Literal->new( '5.3', undef, 'http://www.w3.org/2001/XMLSchema#float' );
my $l01d	= RDF::Query::Node::Literal->new( '01', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l0d		= RDF::Query::Node::Literal->new( '0', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l3dd	= RDF::Query::Node::Literal->new( '3', undef, 'http://www.w3.org/2001/XMLSchema#double' );
my $lpat	= RDF::Query::Node::Literal->new( '^b' );
my $lemail	= RDF::Query::Node::Literal->new( 'mailto:greg@evilfunhouse.com' );

my $ldate2	= RDF::Query::Node::Literal->new( '2008-01-01T00:00:00Z', undef, 'http://www.w3.org/2001/XMLSchema#string' );
my $ldate1	= RDF::Query::Node::Literal->new( '2008-01-01T00:00:00Z' );

my $true	= RDF::Query::Node::Literal->new( 'true', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );
my $false	= RDF::Query::Node::Literal->new( 'false', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );

my $rea		= RDF::Query::Node::Resource->new( 'http://example.org/a' );
my $reb		= RDF::Query::Node::Resource->new( 'http://example.org/b' );
my $lea		= RDF::Query::Node::Literal->new( 'http://example.org/a' );

my $dt2		= RDF::Query::Node::Literal->new( '2007-12-31T23:55:00-05:00', undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
my $dt1		= RDF::Query::Node::Literal->new( '2008-01-01T00:00:00Z', undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );

my $cv		= RDF::Query::Node::Literal->new( '1', undef, 'http://example.org/mytype' );
my $ct		= RDF::Query::Node::Literal->new( 'true', undef, 'http://example.org/mytype' );
my $ct2		= RDF::Query::Node::Literal->new( 'true', undef, 'http://example.org/mytype' );

my $len		= RDF::Query::Node::Literal->new( 'en' );
my $lengb	= RDF::Query::Node::Literal->new( 'en-gb' );
my $lenus	= RDF::Query::Node::Literal->new( 'en-us' );


my $va		= RDF::Query::Node::Variable->new( 'a' );
my $vb		= RDF::Query::Node::Variable->new( 'b' );

my $un		= 'RDF::Query::Expression::Unary';
my $bin		= 'RDF::Query::Expression::Binary';
my $func	= 'RDF::Query::Expression::Function';
my $xsd		= 'http://www.w3.org/2001/XMLSchema#';

local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;

{
	# xsd:integer()
	{
		my $TEST	= 'integer->integer cast';
		my $alg		= $func->new( "${xsd}integer", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}

	{
		my $TEST	= 'string->integer cast';
		my $alg		= $func->new( "${xsd}integer", $l1 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(true)->integer cast';
		my $alg		= $func->new( "${xsd}integer", $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(false)->integer cast';
		my $alg		= $func->new( "${xsd}integer", $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 0, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}

	{
		my $TEST	= 'resource->integer cast (throws)';
		my $alg		= $func->new( "${xsd}integer", $rea );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'double->integer cast (throws)';
		my $alg		= $func->new( "${xsd}integer", $l5d );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::FilterEvaluationError', $TEST;
	}
}


{
	# xsd:decimal()
	{
		my $TEST	= 'integer->decimal cast';
		my $alg		= $func->new( "${xsd}decimal", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#decimal', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(true)->decimal cast';
		my $alg		= $func->new( "${xsd}decimal", $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#decimal', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(false)->decimal cast';
		my $alg		= $func->new( "${xsd}decimal", $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 0, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#decimal', "$TEST datatype" );
	}

	{
		my $TEST	= 'resource->decimal cast (throws)';
		my $alg		= $func->new( "${xsd}decimal", $rea );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'custom->decimal cast';
		my $alg		= $func->new( "${xsd}decimal", $cv );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#decimal', "$TEST datatype" );
	}
}

{
	# xsd:float()
	{
		my $TEST	= 'integer->float cast';
		my $alg		= $func->new( "${xsd}float", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(true)->float cast';
		my $alg		= $func->new( "${xsd}float", $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(false)->float cast';
		my $alg		= $func->new( "${xsd}float", $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 0, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', "$TEST datatype" );
	}

	{
		my $TEST	= 'resource->float cast (throws)';
		my $alg		= $func->new( "${xsd}float", $rea );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'custom->float cast (throws)';
		my $alg		= $func->new( "${xsd}float", $cv );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}
}

{
	# xsd:double()
	{
		my $TEST	= 'integer->double cast';
		my $alg		= $func->new( "${xsd}double", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#double', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(true)->double cast';
		my $alg		= $func->new( "${xsd}double", $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#double', "$TEST datatype" );
	}

	{
		my $TEST	= 'bool(false)->double cast';
		my $alg		= $func->new( "${xsd}double", $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 0, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#double', "$TEST datatype" );
	}

	{
		my $TEST	= 'resource->double cast (throws)';
		my $alg		= $func->new( "${xsd}double", $rea );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'custom->double cast (throws)';
		my $alg		= $func->new( "${xsd}double", $cv );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}
}

{
	# xsd:boolean()
	{
		my $TEST	= 'integer(0)->boolean cast';
		my $alg		= $func->new( "${xsd}boolean", $l0d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 0, "$TEST value" );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= 'integer(1)->boolean cast';
		my $alg		= $func->new( "${xsd}boolean", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= 'resource->boolean cast (throws)';
		my $alg		= $func->new( "${xsd}boolean", $rea );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'custom->boolean cast (throws)';
		my $alg		= $func->new( "${xsd}boolean", $cv );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}

	{
		my $TEST	= 'custom(true)->boolean cast';
		my $alg		= $func->new( "${xsd}boolean", $ct );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, "$TEST value" );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
}

{
	# xsd:string
	{
		my $TEST	= 'literal->string cast';
		my $alg		= $func->new( "${xsd}string", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'a', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', "$TEST datatype" );
	}

	{
		my $TEST	= 'integer->string cast';
		my $alg		= $func->new( "${xsd}string", $l1d );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, '1', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'resource->string cast';
		my $alg		= $func->new( "${xsd}string", $rea );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'http://example.org/a', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', "$TEST datatype" );
	}

	{
		my $TEST	= 'boolean->string cast';
		my $alg		= $func->new( "${xsd}string", $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', "$TEST datatype" );
	}
}

{
	# xsd:dateTime
	{
		my $TEST	= 'literal->dateTime cast';
		my $alg		= $func->new( "${xsd}dateTime", $ldate1 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, '2008-01-01T00:00:00Z', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#dateTime', "$TEST datatype" );
	}

	{
		my $TEST	= 'string->dateTime cast';
		my $alg		= $func->new( "${xsd}dateTime", $ldate2 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, '2008-01-01T00:00:00Z', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#dateTime', "$TEST datatype" );
	}

	{
		my $TEST	= 'string(bad)->dateTime cast (throws)';
		my $alg		= $func->new( "${xsd}dateTime", $la );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}
}

{
	# sparql:str
	{
		my $TEST	= 'str(literal)';
		my $alg		= $func->new( "sparql:str", $ct );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		ok( not($value->has_datatype), "$TEST datatype" );
	}

	{
		my $TEST	= 'str(resource)';
		my $alg		= $func->new( "sparql:str", $reb );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'http://example.org/b', "$TEST value" );
		ok( not($value->has_datatype), "$TEST datatype" );
	}

	{
		my $TEST	= 'str(blank) (throws)';
		my $alg		= $func->new( "sparql:str", $ba );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}
}

{
	# sparql:lang
	{
		my $TEST	= 'lang(plain) is empty';
		my $alg		= $func->new( "sparql:lang", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, '', "$TEST value" );
	}

	{
		my $TEST	= 'lang(english)';
		my $alg		= $func->new( "sparql:lang", $lal );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'en', "$TEST value" );
	}

	{
		my $TEST	= 'lang(blank) (throws)';
		my $alg		= $func->new( "sparql:lang", $ba );
		throws_ok {
			my $value	= $alg->evaluate( undef, {} );
		} 'RDF::Query::Error::TypeError', $TEST;
	}
}

{
	# sparql:bound
	{
		my $TEST	= 'bound(var) true';
		my $alg		= $func->new( "sparql:bound", $va );
		my $value	= $alg->evaluate( undef, { a => $la } );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'bound(var) false';
		my $alg		= $func->new( "sparql:bound", $vb );
		my $value	= $alg->evaluate( undef, { a => $la } );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

}

{
	# sparql:isuri
	# sparql:isiri
	{
		my $TEST	= 'isuri(resource)';
		my $alg		= $func->new( "sparql:isuri", $rea );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isuri(literal)';
		my $alg		= $func->new( "sparql:isuri", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isiri(resource)';
		my $alg		= $func->new( "sparql:isiri", $rea );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isiri(literal)';
		my $alg		= $func->new( "sparql:isiri", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
}

{
	# sparql:isblank
	{
		my $TEST	= 'isblank(resource)';
		my $alg		= $func->new( "sparql:isblank", $rea );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isblank(literal)';
		my $alg		= $func->new( "sparql:isblank", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isblank(blank)';
		my $alg		= $func->new( "sparql:isblank", $ba );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
}

{
	# sparql:isliteral
	{
		my $TEST	= 'isliteral(resource)';
		my $alg		= $func->new( "sparql:isliteral", $rea );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isliteral(literal)';
		my $alg		= $func->new( "sparql:isliteral", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'isliteral(blank)';
		my $alg		= $func->new( "sparql:isliteral", $ba );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
}

{
	# sparql:langmatches
	{
		my $TEST	= 'langmatches(en-gb, en)';
		my $alg		= $func->new( "sparql:langmatches", $lengb, $len );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= 'langmatches(en-us, en-gb)';
		my $alg		= $func->new( "sparql:langmatches", $lenus, $lengb );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
}

{
	# sparql:sameterm
	{
		my $TEST	= 'sameTerm on equivalent dateTime literals';
		my $alg		= $func->new( "sparql:sameterm", $dt1, $dt2 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= 'sameTerm on identical literals';
		my $alg		= $func->new( "sparql:sameterm", $ct, $ct2 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= 'sameTerm on different typed literals with same value';
		my $alg		= $func->new( "sparql:sameterm", $ct, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
}

{
	# sparql:datatype
	{
		my $TEST	= 'datatype(plain literal)';
		my $alg		= $func->new( "sparql:datatype", $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Resource' );
		is( $value->uri_value, 'http://www.w3.org/2001/XMLSchema#string', "$TEST value" );
	}
	
	{
		my $TEST	= 'datatype(dateTime)';
		my $alg		= $func->new( "sparql:datatype", $dt1 );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Resource' );
		is( $value->uri_value, 'http://www.w3.org/2001/XMLSchema#dateTime', "$TEST value" );
	}
	
	{
		my $TEST	= 'datatype(custom typed literal)';
		my $alg		= $func->new( "sparql:datatype", $cv );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Resource' );
		is( $value->uri_value, 'http://example.org/mytype', "$TEST value" );
	}
	
}

{
	# sparql:regex
	{
		my $TEST	= "regex('abcdefg', 'a')";
		my $alg		= $func->new( "sparql:regex", $lalpha, $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= "regex('b', 'a')";
		my $alg		= $func->new( "sparql:regex", $lb, $la );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= "regex('abcdefg', '^b')";
		my $alg		= $func->new( "sparql:regex", $lalpha, $lpat );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= "regex('b', '^b')";
		my $alg		= $func->new( "sparql:regex", $lb, $lpat );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}

	{
		my $TEST	= "regex('ABCDEFG', 'b', 'i')";
		my $alg		= $func->new( "sparql:regex", $lALPHA, $lb, $li );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
}

{
	# sparql:logical-or
	{
		my $TEST	= "logical-or(T,T)";
		my $alg		= $func->new( "sparql:logical-or", $true, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-or(T,F)";
		my $alg		= $func->new( "sparql:logical-or", $true, $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-or(F,T)";
		my $alg		= $func->new( "sparql:logical-or", $false, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-or(F,F)";
		my $alg		= $func->new( "sparql:logical-or", $false, $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-or(F,F,T)";
		my $alg		= $func->new( "sparql:logical-or", $false, $false, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
	}
	
}

{
	# sparql:logical-and
	{
		my $TEST	= "logical-and(T,T)";
		my $alg		= $func->new( "sparql:logical-and", $true, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-and(T,F)";
		my $alg		= $func->new( "sparql:logical-and", $true, $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-and(F,T)";
		my $alg		= $func->new( "sparql:logical-and", $false, $true );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-and(F,F)";
		my $alg		= $func->new( "sparql:logical-and", $false, $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
	}
	
	{
		my $TEST	= "logical-and(T,T,F)";
		my $alg		= $func->new( "sparql:logical-and", $true, $true, $false );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
	}
}

{
	# jena:sha1sum
	# jena:now
	# jena:langeq
	# jena:listMember
	{
		my $TEST	= "jena:sha1sum";
		my $alg		= $func->new( "java:com.hp.hpl.jena.query.function.library.sha1sum", $lemail );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8', "$TEST value" );
	}
	
	{
		my $TEST	= "jena:now";
		my $alg		= $func->new( "java:com.hp.hpl.jena.query.function.library.now" );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		like( $value->literal_value, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, "$TEST value" );
	}
	
	{
		my $TEST	= "jena:langeq (true)";
		my $alg		= $func->new( "java:com.hp.hpl.jena.query.function.library.langeq", $lal, $len );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= "jena:langeq (false)";
		my $alg		= $func->new( "java:com.hp.hpl.jena.query.function.library.langeq", $lal, $lengb );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		local($TODO)	= "can't test jena:listMember yet because this test script doesn't instantiate a model";
		my $TEST	= "jena:listMember";
		fail();
	}
	
}

{
	eval "use Geo::Distance 0.09;";
	my $GEO_DISTANCE_LOADED	= ($@) ? 0 : 1;
	# ldodds:Distance
	SKIP: {
		skip( "Need Geo::Distance 0.09 or higher to run these tests.", 4 ) unless ($GEO_DISTANCE_LOADED);
		my @args	= map { RDF::Query::Node::Literal->new($_, undef, 'http://www.w3.org/2001/XMLSchema#float') } qw(34.015673 -118.496947 41.8351 -71.3971);
		my $TEST	= "ldodds:Distance";
		my $alg		= $func->new( "java:com.ldodds.sparql.Distance", @args );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		my $dist	= $value->numeric_value;
		cmp_ok( $dist, '>', 4165, "$TEST value lower bound" );
		cmp_ok( $dist, '<', 4170, "$TEST value upper bound" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', "$TEST datatype" );
	}
}

SKIP: {
	# kasei:bloom
	unless ($RDF::Query::Functions::BLOOM_FILTER_LOADED) {
		skip('Bloom::Filter is not available', 7);
	}
	
	{
		my $TEST	= "bloom:filter";
		my $filter	= RDF::Query::Node::Literal->new( 'AAAAAgAAAAcAAAACAAAAAgAAAAEAAAADklyWOSVq5odsMC4y' );
		my $alg		= $func->new( "http://kasei.us/code/rdf-query/functions/bloom/filter", $va, $filter );
		
		{
			my $value	= $alg->evaluate( undef, { a => $rea } );
			isa_ok( $value, 'RDF::Query::Node::Literal' );
			is( $value->literal_value, 'true', "$TEST value" );
			is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
		}
		
		{
			my $value	= $alg->evaluate( undef, { a => $reb } );
			isa_ok( $value, 'RDF::Query::Node::Literal' );
			is( $value->literal_value, 'true', "$TEST value" );
			is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
		}
		
		my @resources	= map { RDF::Query::Node::Resource->new( 'http://localhost/' . $_ ) } ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
		my $true	= 0;
		foreach my $r (@resources) {
			my $value	= $alg->evaluate( undef, { a => $r } );
			if ($value->literal_value eq 'true') {
				$true++;
			}
		}
		cmp_ok( $true, '<', scalar(@resources), "$TEST (false)");
	}
}

################################################################################

{
	# nested
	{
		my $TEST	= 'datatype(jena:now())';
		my $now		= $func->new( "java:com.hp.hpl.jena.query.function.library.now" );
		my $alg		= $func->new( "sparql:datatype", $now );
		my $value	= $alg->evaluate( undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Resource' );
		is( $value->uri_value, 'http://www.w3.org/2001/XMLSchema#dateTime', "$TEST datatype" );
	}
}


__END__

