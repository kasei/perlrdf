use Test::More tests => 22;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use File::Temp qw(tempfile);
use Data::Dumper;

use_ok( 'RDF::Trine::Model::RDFS' );

use RDF::Trine::Parser;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace qw(rdf rdfs foaf);

my $agent3	= RDF::Trine::Node::Resource->new('http://xmlns.com/wordnet/1.6/Agent-3');
my $data_person	= <<'END';
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
foaf:Person a rdfs:Class ;
	rdfs:subClassOf foaf:Agent .
foaf:Agent rdfs:subClassOf <http://xmlns.com/wordnet/1.6/Agent-3> .
END

my ($stores, $remove)	= stores();
foreach my $store (@$stores) {
	isa_ok( $store, 'RDF::Trine::Store::DBI' );
	my $model	= RDF::Trine::Model::RDFS->new( $store );
	isa_ok( $model, 'RDF::Trine::Model' );
	
	local($RDF::Trine::Parser::Turtle::debug)	= 1;
	my $parser	= RDF::Trine::Parser->new('turtle');
	my $base	= RDF::Trine::Node::Resource->new('http://example.org/');
	
	$parser->parse_into_model( $base, $data_person, $model );
	is( $model->count_statements, 3, 'initial model size' );
	
	{
		my $iter	= $model->get_statements( $foaf->Person, $rdfs->subClassOf, $agent3 );
		my ($st)	= $iter->next;
		is( $st, undef, 'expected missing subClassOf triple' );
	}
	
	$model->run_inference;
	is( $model->count_statements, 15, 'model size after inference' );
	
	{
		my $iter	= $model->get_statements( $foaf->Person, $rdfs->subClassOf, $agent3 );
		my ($st)	= $iter->next;
		isa_ok( $st, 'RDF::Trine::Statement', 'expected inferred subClassOf triple' );
	}
	
	$model->clear_inference;
	is( $model->count_statements, 3, 'model size after removing inferences' );
}

foreach my $file (@$remove) {
	unlink( $file );
}

sub stores {
	my @stores;
	my @removeme;
	{
		my $store	= RDF::Trine::Store::DBI->new();
		$store->init();
		push(@stores, $store);
	}
	
	{
		my ($fh, $filename) = tempfile();
		undef $fh;
		my $dbh		= DBI->connect( "dbi:SQLite:dbname=${filename}", '', '' );
		my $store	= RDF::Trine::Store::DBI->new( 'model', $dbh );
		$store->init();
		push(@stores, $store);
		push(@removeme, $filename);
	}
	
	{
		my ($fh, $filename) = tempfile();
		undef $fh;
		my $dsn		= "dbi:SQLite:dbname=${filename}";
		my $store	= RDF::Trine::Store::DBI->new( 'model', $dsn, '', '' );
		$store->init();
		push(@stores, $store);
		push(@removeme, $filename);
	}
	return (\@stores, \@removeme);
}
