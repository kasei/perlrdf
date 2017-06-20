use Test::More tests => 18;
use Test::Exception;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;

use RDF::Trine qw(iri variable statement);
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser;

my $store	= RDF::Trine::Store::SPARQL->new('http://myrdf.us/sparql11');
my $model	= RDF::Trine::Model->new( $store );

throws_ok { $store->add_statement() } 'RDF::Trine::Error::MethodInvocationError', 'add_statement throws error with no statement';
throws_ok { $store->remove_statement() } 'RDF::Trine::Error::MethodInvocationError', 'remove_statement throws error with no statement';
# throws_ok { $store->remove_statements(iri('asdfkj')) } 'RDF::Trine::Error::UnimplementedError', 'remove_statements throws unimplemented error';

my $subject = iri('http://example.org/resource/1');
my $subject2 = iri('http://example.org/resource/2');
my $predicate = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
my $object = iri('http://example.org/vocab/Record');
my $statement = statement($subject, $predicate, $object);
my $statement2 = statement($subject2, $predicate, $object);

GROUP_BULK_OPS: {
    my @bulk_ops = ();
    push(@bulk_ops, ['_add_statements', $statement, undef]);
    push(@bulk_ops, ['_add_statements', $statement2, undef]);
    my @aggops = $store->_group_bulk_ops( @bulk_ops );
    is(scalar @aggops, 1, "There should just be one _add_statements aggregated operation");
    my $aggop = shift @aggops;
    my ($type, $ops) = @$aggop;
    is($type, '_add_statements', "Type is correct: _add_statements");
    is(scalar @$ops, 2, 'There should be two ops here');
}

BULK_OPS_INTEGRATION: {
    no warnings 'redefine';
    local *RDF::Trine::Store::SPARQL::_get_post_iterator = sub {
        my ($self,$sparql) = @_;
        my @statements = ();
        if ($sparql =~ /INSERT DATA [{](.*)[}]/s){
            my $ntriples = $1;
            if ($ntriples){
                my $parser = RDF::Trine::Parser->new('ntriples');
                $parser->parse(undef, $ntriples, sub { my $st  = shift; push(@statements,$st); } );
            }
        }
        is(@statements,2,"There should be two statements being posted.");

        #This boolean isn't really checked so just default to true
        return RDF::Trine::Iterator::Boolean->new( [ 1 ] );
     };
    $store->_begin_bulk_ops;
    $store->add_statement($statement);
    $store->add_statement($statement2);
    $store->_end_bulk_ops;
}

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

subtest 'test remove_statements interface' => sub {
    plan tests => 8;

    no warnings 'redefine';
    my $cached_sparql;
    local *RDF::Trine::Store::SPARQL::_get_post_iterator = sub {
        my ($self,$sparql) = @_;
        #Cache the SPARQL at subroutine scope for testing
        $cached_sparql = $sparql;
        #This boolean isn't really checked so just default to true
        return RDF::Trine::Iterator::Boolean->new( [ 1 ] );
    };

    my $store   = RDF::Trine::Store::SPARQL->new('http://localhost/sparql');

    my $subject = iri('http://example.org/resource/1');
    my $predicate = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
    my $object = iri('http://example.org/vocab/Record');
    my $context = iri('http://example.org/graph/1');
    my $triple = statement($subject, $predicate, $object);
    my $quad = statement($subject, $predicate, $object, $context);
    
    lives_ok {  $store->remove_statements($triple) } 'Use non-standard interface for remove_statements w/ triple';
    is( $cached_sparql, 'DELETE WHERE { <http://example.org/resource/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab/Record> . }','SPARQL OK');
    
    lives_ok {  $store->remove_statements($quad) } 'Use non-standard interface for remove_statements w/ quad';
    is( $cached_sparql, 'DELETE WHERE { GRAPH <http://example.org/graph/1> { <http://example.org/resource/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab/Record> } }', 'SPARQL OK');
    
    lives_ok {  $store->remove_statements($subject, $predicate, $object, $context) } 'Use standard interface for remove_statements w/ context';
    is( $cached_sparql, 'DELETE WHERE { GRAPH <http://example.org/graph/1> { <http://example.org/resource/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab/Record> } }', 'SPARQL OK');
    
    lives_ok {  $store->remove_statements($subject, $predicate, $object, undef) } 'Use standard interface for remove_statements w/o context';
    is( $cached_sparql, 'DELETE WHERE { <http://example.org/resource/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab/Record> . }','SPARQL OK');
};
