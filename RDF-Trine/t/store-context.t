use Test::More;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace;

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $g		= RDF::Trine::Node::Blank->new();
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, RDF::Trine::Node::Resource->new('http://kasei.us/') );

my @stores	= test_stores();
plan tests => scalar(@stores) * 6;
foreach my $store (@stores) {
	print "### Testing store " . ref($store) . "\n";
	isa_ok( $store, 'RDF::Trine::Store' );
	
	{
		$store->add_statement( $_ ) for ($st0, $st1, $st2);
		my $stream	= $store->get_contexts;
		my $c		= $stream->next;
		isa_ok( $c, 'RDF::Trine::Node::Nil' );
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
			'(nil)'	=> 1,
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
			'(nil)'	=> 1,
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
			'(nil)'	=> 1,
			'(blankContext)'	=> 1,
			'"Literal Context"'	=> 1,
			'<http://kasei.us/about/foaf.xrdf>'	=> 1,
		);
		is_deeply( \%seen, \%expect, 'expected contexts' );
	}
}

sub test_stores {
	my @stores;
	push(@stores, RDF::Trine::Store::DBI->temporary_store());
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	return @stores;
}
