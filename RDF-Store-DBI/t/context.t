use Test::More tests => 10;

use strict;
use warnings;

use RDF::Query::Node;
use RDF::Query::Algebra;
use RDF::Store::DBI;
use RDF::Namespace;

my $store	= RDF::Store::DBI->temporary_store();
isa_ok( $store, 'RDF::Store::DBI' );


my $rdf		= RDF::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Namespace->new('http://kasei.us/');

my $g		= RDF::Query::Node::Blank->new();
my $st0		= RDF::Query::Algebra::Triple->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Query::Algebra::Triple->new( $g, $foaf->name, RDF::Query::Node::Literal->new('Greg') );
my $st2		= RDF::Query::Algebra::Triple->new( $g, $foaf->homepage, RDF::Query::Node::Resource->new('http://kasei.us/') );

{
	$store->add_statement( $_ ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	is( $c, undef, 'no contexts' );
}

{
	my $ctx		= RDF::Query::Node::Resource->new('http://kasei.us/about/foaf.xrdf');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	isa_ok( $c, 'RDF::Query::Node::Resource' );
	is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
	is( $stream->next, undef );
}

{
	my $ctx		= RDF::Query::Node::Literal->new('Literal Context');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $count	= 0;
	while (my $c = $stream->next) {
		isa_ok( $c, 'RDF::Query::Node' );
		if ($c->isa('RDF::Query::Node::Resource')) {
			is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
		} else {
			is( $c->literal_value, 'Literal Context', 'context literal' );
		}
		$count++;
	}
	is( $count, 2, 'two contexts' );
}

