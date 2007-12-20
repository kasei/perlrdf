use Test::More tests => 17;

use strict;
use warnings;

use RDF::Trice::Node;
use RDF::Trice::Statement;
use RDF::Trice::Store::DBI;
use RDF::Trice::Namespace;

my $store	= RDF::Trice::Store::DBI->temporary_store();
isa_ok( $store, 'RDF::Trice::Store::DBI' );


my $rdf		= RDF::Trice::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trice::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trice::Namespace->new('http://kasei.us/');

my $g		= RDF::Trice::Node::Blank->new();
my $st0		= RDF::Trice::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trice::Statement->new( $g, $foaf->name, RDF::Trice::Node::Literal->new('Greg') );
my $st2		= RDF::Trice::Statement->new( $g, $foaf->homepage, RDF::Trice::Node::Resource->new('http://kasei.us/') );

{
	$store->add_statement( $_ ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	is( $c, undef, 'no contexts' );
}

{
	my $ctx		= RDF::Trice::Node::Resource->new('http://kasei.us/about/foaf.xrdf');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	isa_ok( $c, 'RDF::Trice::Node::Resource' );
	is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
	is( $stream->next, undef );
}

{
	my $ctx		= RDF::Trice::Node::Literal->new('Literal Context');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $count	= 0;
	while (my $c = $stream->next) {
		isa_ok( $c, 'RDF::Trice::Node' );
		if ($c->isa('RDF::Trice::Node::Resource')) {
			is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
		} else {
			is( $c->literal_value, 'Literal Context', 'context literal' );
		}
		$count++;
	}
	is( $count, 2, 'two contexts' );
}

{
	my $ctx		= RDF::Trice::Node::Blank->new('blank-context');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $count	= 0;
	while (my $c = $stream->next) {
		isa_ok( $c, 'RDF::Trice::Node' );
		if ($c->isa('RDF::Trice::Node::Resource')) {
			is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
		} elsif ($c->isa('RDF::Trice::Node::Literal')) {
			is( $c->literal_value, 'Literal Context', 'context literal' );
		} else {
			is( $c->blank_identifier, 'blank-context', 'context bnode' );
		}
		$count++;
	}
	is( $count, 3, 'three contexts' );
}

