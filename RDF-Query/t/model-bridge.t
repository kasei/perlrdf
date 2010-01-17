#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;
use Test::Exception;
use Scalar::Util qw(refaddr);

use lib qw(. t);
BEGIN { require "models.pl"; }

$ENV{RDFQUERY_USE_MYSQL}		= 1;
$ENV{RDFQUERY_USE_DBI_MODEL}	= 1;

my @files	= ();
my @models	= test_models_and_classes( @files );

plan tests => 1 + (47 * scalar(@models)) + (scalar(@models) * (scalar(@models) - 1));

use_ok( 'RDF::Query' );

foreach my $data (@models) {
	my $class	= $data->{ class };
	my $model	= $data->{ modelobj };
	
	foreach my $other (@models) {
		next if (refaddr($other) == refaddr($data));
		if ($other->{class} eq $class) {
			SKIP: {
				skip "ignoring distinct models with same model class", 1;
			}
		} else {
			throws_ok { $class->new($other->{modelobj}) } 'RDF::Query::Error::MethodInvocationError', 'constructor throws exception with wrong model';
		}
	}
	
	print "\n#################################\n";
	print "### Using model: $model\n";
	
	dies_ok { $class->new( 'foo' ) } 'non-model constructor arg dies';
	
	SKIP: {
		skip "This backend does not support temporary models", 1 unless $class->supports('temp_model');
		my $bridge	= $class->new();
		isa_ok( $bridge, $data->{class} );
	}
	
	my $bridge	= $class->new( $model );
	isa_ok( $bridge, $data->{class} );
	
	is( refaddr( $bridge->model ), refaddr( $model ), 'model accessor' );
	
	### URI NODES
	
	{
		my $uri		= 'http://example.com';
		my $node	= $bridge->new_resource( $uri );
		isa_ok( $node, 'RDF::Trine::Node::Resource' );
		is( $bridge->uri_value( $node ), $uri, 'resource value check' );
		ok( $bridge->is_node( $node ), 'resource node check' );
		ok( $bridge->is_resource( $node ), 'resource resource check' );
		ok( not($bridge->is_literal( $node )), 'resource literal check' );
		ok( not($bridge->is_blank( $node )), 'resource blank check' );
	}
	
	### BLANK NODES
	
	{
		my $name	= 'baz';
		my $node	= $bridge->new_blank( $name );
		isa_ok( $node, 'RDF::Trine::Node::Blank' );
		is( $bridge->blank_identifier( $node ), $name, 'blank identifier check' );
		ok( $bridge->is_node( $node ), 'blank check' );
		ok( not($bridge->is_resource( $node )), 'blank resource check' );
		ok( not($bridge->is_literal( $node )), 'blank literal check' );
		ok( $bridge->is_blank( $node ), 'blank blank check' );
	}
	
	{
		my $node	= $bridge->new_blank();
		my $node2	= $bridge->new_blank();
		isa_ok( $node, 'RDF::Trine::Node::Blank' );
		cmp_ok( $bridge->blank_identifier( $node ), 'ne', $bridge->blank_identifier( $node2 ), 'generated blank identifier check' );
		ok( $bridge->is_node( $node ), 'blank check' );
		ok( not($bridge->is_resource( $node )), 'blank resource check' );
		ok( not($bridge->is_literal( $node )), 'blank literal check' );
		ok( $bridge->is_blank( $node ), 'blank blank check' );
	}
	
	### LITERAL NODES
	
	{	# simple
		my $value	= 'quux';
		my $node	= $bridge->new_literal( $value );
		isa_ok( $node, 'RDF::Trine::Node::Literal' );
		is( $bridge->literal_value( $node ), $value, 'literal value check' );
		ok( $bridge->is_node( $node ), 'literal check' );
		ok( not($bridge->is_resource( $node )), 'literal resource check' );
		ok( $bridge->is_literal( $node ), 'literal literal check' );
		ok( not($bridge->is_blank( $node )), 'literal blank check' );
	}
	
	{	# language-typed
		use utf8;
		my $value	= '火星';
		my $node	= $bridge->new_literal( $value, 'ja' );
		isa_ok( $node, 'RDF::Trine::Node::Literal' );
		is( $bridge->literal_value( $node ), $value, 'literal value check' );
		is( $bridge->literal_value_language( $node ), 'ja', 'literal value language check' );
		ok( $bridge->is_node( $node ), 'literal check' );
		ok( not($bridge->is_resource( $node )), 'literal resource check' );
		ok( $bridge->is_literal( $node ), 'literal literal check' );
		ok( not($bridge->is_blank( $node )), 'literal blank check' );
	}
	
	{	# data-typed
		my $value	= '123';
		my $dt		= 'http://www.w3.org/2001/XMLSchema#int';
		my $node	= $bridge->new_literal( $value, undef, $dt );
		isa_ok( $node, 'RDF::Trine::Node::Literal' );
		is( $bridge->literal_value( $node ), $value, 'literal value check' );
		is( $bridge->literal_datatype( $node ), $dt, 'literal datatype check' );
		ok( $bridge->is_node( $node ), 'literal check' );
		ok( not($bridge->is_resource( $node )), 'literal resource check' );
		ok( $bridge->is_literal( $node ), 'literal literal check' );
		ok( not($bridge->is_blank( $node )), 'literal blank check' );
	}
	
	### NODE EQUALITY
	
	{
		my $l1	= $bridge->new_literal( 'schadenfreude', 'de' );
		my $l2	= $bridge->new_literal( 'schadenfreude' );
		ok( not($bridge->equals( $l1, $l2 )), 'literal language equality' );
		
	}
	
	### STATEMENTS
	
	{
		my $subj	= $bridge->new_blank();
		my $pred	= $bridge->new_resource( 'http://xmlns.com/foaf/0.1/name' );
		my $obj		= $bridge->new_literal( 'greg' );
		my $st		= $bridge->new_statement( $subj, $pred, $obj );
		
		isa_ok( $st, 'RDF::Trine::Statement' );
		ok( $bridge->is_blank( $bridge->subject( $st ) ), 'subject accessor' );
		ok( $bridge->is_resource( $bridge->predicate( $st ) ), 'predicate accessor' );
		ok( $bridge->is_literal( $bridge->object( $st ) ), 'object accessor' );
	}
}

__END__
