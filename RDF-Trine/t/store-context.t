use Test::More;
use Test::Moose;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, RDF::Trine::Node::Resource->new('http://kasei.us/') );

my @stores	= test_stores();
plan tests => scalar(@stores) * 5;
foreach my $store (@stores) {
	print "### Testing store " . ref($store) . "\n";
	does_ok( $store, 'RDF::Trine::Store::API' );
	
	{
		$store->add_statement( $_ ) for ($st0, $st1, $st2);
		my $stream	= $store->get_contexts;
		my $c		= $stream->next;
		is( $stream->next, undef, 'expected end-of-iterator' );
	}
	
	{
		my $ctx		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf');
		$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
		my $stream	= $store->get_contexts;
		my %seen;
		while (my $c = $stream->next) {
			$seen{ $c->as_string }++;
		}
		my %expect	= (
			'<http://kasei.us/about/foaf.xrdf>'	=> 1,
		);
		is_deeply( \%seen, \%expect, 'expected contexts' );
	}
	
	{
		my $ctx		= RDF::Trine::Node::Literal->new('Literal Context');
		$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
		my $stream	= $store->get_contexts;
		my %seen;
		while (my $c = $stream->next) {
			$seen{ $c->as_string }++;
		}
		my %expect	= (
			'"Literal Context"'	=> 1,
			'<http://kasei.us/about/foaf.xrdf>'	=> 1,
		);
		is_deeply( \%seen, \%expect, 'expected contexts' );
	}
	
	{
		my $ctx		= RDF::Trine::Node::Blank->new('blankContext');
		$store->add_statement( $_, $ctx ) for ($st0, $st1, $st2);
		my $stream	= $store->get_contexts;
		my %seen;
		while (my $c = $stream->next) {
			$seen{ $c->as_string }++;
		}
		my %expect	= (
			'(blankContext)'	=> 1,
			'"Literal Context"'	=> 1,
			'<http://kasei.us/about/foaf.xrdf>'	=> 1,
		);
		is_deeply( \%seen, \%expect, 'expected contexts' );
	}
}

sub test_stores {
	my @stores;
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	return @stores;
}
