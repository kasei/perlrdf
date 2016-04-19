#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 42;
use Scalar::Util qw(reftype blessed);

use RDF::Query::Node;
use RDF::Query::Algebra;

my $bz		= RDF::Query::Node::Blank->new( 'z' );
my $bb		= RDF::Query::Node::Blank->new( 'b' );
my $ba		= RDF::Query::Node::Blank->new( 'a' );

my $lb		= RDF::Query::Node::Literal->new( 'b' );
my $la		= RDF::Query::Node::Literal->new( 'a' );
my $lal		= RDF::Query::Node::Literal->new( 'a', 'en' );
my $l1		= RDF::Query::Node::Literal->new( '1' );
my $l2d		= RDF::Query::Node::Literal->new( '2.0', undef, 'http://www.w3.org/2001/XMLSchema#float' );
my $l1d		= RDF::Query::Node::Literal->new( '1', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l4d		= RDF::Query::Node::Literal->new( '-4', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l5d		= RDF::Query::Node::Literal->new( '5.3', undef, 'http://www.w3.org/2001/XMLSchema#float' );
my $l01d	= RDF::Query::Node::Literal->new( '01', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l0d		= RDF::Query::Node::Literal->new( '0', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
my $l3dd	= RDF::Query::Node::Literal->new( '3', undef, 'http://www.w3.org/2001/XMLSchema#double' );
my $true	= RDF::Query::Node::Literal->new( 'true', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );
my $false	= RDF::Query::Node::Literal->new( 'false', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );

my $rea		= RDF::Query::Node::Resource->new( 'http://example.org/a' );
my $reb		= RDF::Query::Node::Resource->new( 'http://example.org/b' );
my $lea		= RDF::Query::Node::Literal->new( 'http://example.org/a' );

my $dt3		= RDF::Query::Node::Literal->new( '2007-12-31T22:55:00-06:00', undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
my $dt2		= RDF::Query::Node::Literal->new( '2007-12-31T23:55:00-05:00', undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
my $dt1		= RDF::Query::Node::Literal->new( '2008-01-01T00:00:00Z', undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );

my $cv		= RDF::Query::Node::Literal->new( '1', undef, 'http://example.org/mytype' );
my $ct		= RDF::Query::Node::Literal->new( 'true', undef, 'http://example.org/mytype' );

my $un	= 'RDF::Query::Expression::Unary';
my $bin	= 'RDF::Query::Expression::Binary';

{
	# NUMERIC OPERATORS
	{
		my $TEST	= 'integer add';
		my $plus	= $bin->new( '+', $l1d, $l01d );
		my $value	= $plus->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 2, "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}
	
	{
		my $plus	= $bin->new( '+', $l1d, $l2d );
		my $value	= $plus->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 3, 'integer-float add value' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', 'integer-float add datatype' );
	}
	
	{
		my $diff	= $bin->new( '-', $l0d, $l1d );
		my $value	= $diff->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, -1, 'integer subtract value' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', 'integer subtract datatype' );
	}
	
	{
		my $diff	= $bin->new( '-', $l2d, $l1d );
		my $value	= $diff->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1, 'integer-float subtract value' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', 'integer-float subtract datatype' );
	}
	
	{
		my $prod	= $bin->new( '*', $l2d, $l3dd );
		my $value	= $prod->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 6, 'doule-float quotient value' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#double', 'double-float quotient datatype' );
	}
	
	{
		my $quo		= $bin->new( '/', $l3dd, $l2d );
		my $value	= $quo->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 1.5, 'doule-float quotient value' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#double', 'double-float quotient datatype' );
	}

	{
		my $TEST	= 'integer unary-plus';
		my $plus	= $un->new( '+', $l4d );
		my $value	= $plus->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, -4, $TEST );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}

	{
		my $TEST	= 'integer unary-minus';
		my $plus	= $un->new( '-', $l4d );
		my $value	= $plus->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, 4, $TEST );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', "$TEST datatype" );
	}
	
	{
		my $sum		= $bin->new( '+', $l1d, $l2d );
		my $diff	= $bin->new( '-', $l0d, $l1d );
		my $prod	= $bin->new( '*', $sum, $diff );
		my $value	= $prod->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->numeric_value, -3, 'prod(sum, diff)' );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#float', 'double-float quotient datatype' );
	}
	
}

{
	# RELATIONAL OPERATORS
	local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
	{
		my $TEST	= 'double-float less-than';
		my $lt		= $bin->new( '<', $l3dd, $l2d );
		my $value	= $lt->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'false', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'resource-float less-than';
		my $lt		= $bin->new( '<', $rea, $l2d );
		my $value	= $lt->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'literal-blank greater-than';
		my $lt		= $bin->new( '>', $la, $ba );
		my $value	= $lt->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'dateTime less-than';
		my $lt		= $bin->new( '<', $dt1, $dt2 );
		my $value	= $lt->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
	
	{
		my $TEST	= 'dateTime equal';
		my $lt		= $bin->new( '==', $dt3, $dt2 );
		my $value	= $lt->evaluate( undef, undef, {} );
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		is( $value->literal_value, 'true', "$TEST value" );
		is( $value->literal_datatype, 'http://www.w3.org/2001/XMLSchema#boolean', "$TEST datatype" );
	}
}





