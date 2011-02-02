use Test::More tests => 13;
use Test::Exception;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;

use RDF::Trine qw(iri variable statement);
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser;

my $store	= RDF::Trine::Store::SPARQL->new('http://kasei.us/sparql');
my $model	= RDF::Trine::Model->new( $store );

throws_ok { $store->add_statement() } 'RDF::Trine::Error::MethodInvocationError', 'add_statement throws error with no statement';
throws_ok { $store->remove_statement() } 'RDF::Trine::Error::MethodInvocationError', 'remove_statement throws error with no statement';
# throws_ok { $store->remove_statements(iri('asdfkj')) } 'RDF::Trine::Error::UnimplementedError', 'remove_statements throws unimplemented error';

SKIP: {
	unless ($ENV{RDFTRINE_NETWORK_TESTS}) {
		skip( "No network. Set RDFTRINE_NETWORK_TESTS to run these tests.", 11 );
	}
	
	{
		my $iter	= $model->get_statements( undef, $rdf->type, $foaf->Person );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $st		= $iter->next;
		isa_ok( $st, 'RDF::Trine::Statement' );
		my $p		= $st->subject;
		isa_ok( $p, 'RDF::Trine::Node' );
	}
	
	{
		my $iter	= $model->get_statements( variable('s'), $rdf->type, $foaf->Person );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $st		= $iter->next;
		isa_ok( $st, 'RDF::Trine::Statement' );
		my $p		= $st->subject;
		isa_ok( $p, 'RDF::Trine::Node' );
	}
	
	{
		my $count	= $model->size;
		cmp_ok( $count, '>', 0, 'size' );
	}
	
	{
		my $count	= $model->count_statements( undef, $rdf->type, $foaf->Person );
		cmp_ok( $count, '>', 0, 'count_statements' );
	}
	
	{
		my $pattern	= statement( variable('p'), $rdf->type, $foaf->Person );
		my $iter	= $model->get_pattern( $pattern );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $b	= $iter->next;
		isa_ok( $b, 'HASH' );
		isa_ok( $b->{p}, 'RDF::Trine::Node' );
	}
	
	if (0) {
		my @ctx	= $model->get_contexts;
		is_deeply( \@ctx, [], 'empty get_contexts' );
	}
}
