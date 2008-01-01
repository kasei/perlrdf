use Test::More tests => 17;

use strict;
use warnings;

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace;

my $store	= RDF::Trine::Store::DBI->temporary_store();
isa_ok( $store, 'RDF::Trine::Store::DBI' );


my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, RDF::Trine::Node::Resource->new('http://kasei.us/') );

{
	$store->add_statement( $_ ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	is( $c, undef, 'no contexts' );
}

{
	my $ctx		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $c		= $stream->next;
	isa_ok( $c, 'RDF::Trine::Node::Resource' );
	is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
	is( $stream->next, undef );
}

{
	my $ctx		= RDF::Trine::Node::Literal->new('Literal Context');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $count	= 0;
	while (my $c = $stream->next) {
		isa_ok( $c, 'RDF::Trine::Node' );
		if ($c->isa('RDF::Trine::Node::Resource')) {
			is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
		} else {
			is( $c->literal_value, 'Literal Context', 'context literal' );
		}
		$count++;
	}
	is( $count, 2, 'two contexts' );
}

{
	my $ctx		= RDF::Trine::Node::Blank->new('blank-context');
	$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
	my $stream	= $store->get_contexts;
	my $count	= 0;
	while (my $c = $stream->next) {
		isa_ok( $c, 'RDF::Trine::Node' );
		if ($c->isa('RDF::Trine::Node::Resource')) {
			is( $c->uri_value, 'http://kasei.us/about/foaf.xrdf', 'context uri' );
		} elsif ($c->isa('RDF::Trine::Node::Literal')) {
			is( $c->literal_value, 'Literal Context', 'context literal' );
		} else {
			is( $c->blank_identifier, 'blank-context', 'context bnode' );
		}
		$count++;
	}
	is( $count, 3, 'three contexts' );
}

