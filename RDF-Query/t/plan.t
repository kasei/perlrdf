#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More;
use Data::Dumper;

use lib qw(. t);
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel          = TRACE, Screen
# 	log4perl.category.rdf.query.algebra.service          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $model_tests		= 122;
my $file	= 'data/foaf.xrdf';
my %named	= map { $_ => URI::file->new_abs( File::Spec->rel2abs("data/named_graphs/$_") ) } qw(alice.rdf bob.rdf meta.rdf repeats1.rdf repeats2.rdf);
my @models	= test_models_and_classes($file);

eval { require LWP::Simple };
if ($@) {
	plan skip_all => "LWP::Simple is not available for loading <http://...> URLs";
	return;
} elsif (not exists $ENV{RDFQUERY_DEV_TESTS}) {
	plan skip_all => 'Developer tests. Set RDFQUERY_DEV_TESTS to run these tests.';
	return;
} elsif (exists $ENV{RDFQUERY_NETWORK_TESTS}) {
	plan tests => scalar(@models) * $model_tests;
} else {
	plan skip_all => 'No network. Set RDFQUERY_DEV_TESTS and set RDFQUERY_NETWORK_TESTS to run these tests.';
	return;
}

use RDF::Query;
use RDF::Trine::Namespace qw(rdf foaf);

use RDF::Query::Plan::Service;
use RDF::Query::Plan::Project;
use RDF::Query::Plan::Offset;
use RDF::Query::Plan::Union;
use RDF::Query::Plan::Triple;
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Distinct;
use RDF::Query::Plan::Join::NestedLoop;

foreach my $data (@models) {
	my $bridge	= $data->{bridge};
	my $model	= $data->{modelobj};
	foreach my $uri (values %named) {
		$bridge->add_uri( "$uri", 1 );
	}
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	my $context	= RDF::Query::ExecutionContext->new(
					bound	=> {},
					model	=> $bridge,
				);
	
	{
		# simple triple
		my @triple	= (
			RDF::Trine::Node::Variable->new('p'),
			$rdf->type,
			$foaf->Person,
		);
		my $plan	= RDF::Query::Plan::Triple->new( @triple );
		
		my $count	= 0;
		$plan->execute( $context );
		while (my $row = $plan->next) {
			isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
			$count++;
		}
		$plan->close;
		is( $count, 4, "expected result count for triple (?p a foaf:Person)" );
	}

	{
		# repeats of the same variable in one triple
		my @triple	= (
			RDF::Trine::Node::Variable->new('type'),
			RDF::Trine::Node::Variable->new('type'),
			RDF::Trine::Node::Variable->new('obj'),
		);
		my $plan	= RDF::Query::Plan::Triple->new( @triple );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				$count++;
			}
			is( $count, 1, "expected result count for triple with repeated variables (pass $pass)" );
			$plan->close;
		}
	}

	{
		# simple quad
		my @quad	= (
			RDF::Trine::Node::Variable->new('p'),
			$foaf->name,
			RDF::Trine::Node::Variable->new('name'),
			RDF::Trine::Node::Variable->new('c'),
		);
		my $plan	= RDF::Query::Plan::Quad->new( @quad );
		
		my $count	= 0;
		$plan->execute( $context );
		while (my $row = $plan->next) {
			isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
			my $name	= lc($row->{name}->literal_value);
			like( $row->{name}, qr#(Alice|Bob)#i, 'expected person name from named graph' );
			like( $row->{c}, qr#${name}[.]rdf>$#, 'graph name matches person name' );
			$count++;
		}
		$plan->close;
		is( $count, 2, "expected result count for quad (?p foaf:name ?name ?c)" );
	}
	
	{
		# repeats of the same variable in one quad
		my @quad	= (
			RDF::Trine::Node::Variable->new('prop'),
			RDF::Trine::Node::Variable->new('prop'),
			RDF::Trine::Node::Variable->new('obj'),
			RDF::Trine::Node::Variable->new('c'),
		);
		my $plan	= RDF::Query::Plan::Quad->new( @quad );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				like( $row->{prop}, qr[#(type|label)>$], 'expected property' );
				$count++;
			}
			is( $count, 2, "expected result count for quad with repeated variables (pass $pass)" );
			$plan->close;
		}
	}
	
	{
		# repeats of the same variable in one quad, constrained to a specific graph
		my @quad	= (
			RDF::Trine::Node::Variable->new('prop'),
			RDF::Trine::Node::Variable->new('prop'),
			RDF::Trine::Node::Variable->new('obj'),
			RDF::Trine::Node::Resource->new("$named{'repeats1.rdf'}"),
		);
		my $plan	= RDF::Query::Plan::Quad->new( @quad );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				like( $row->{prop}, qr[#type>$], 'expected property' );
				$count++;
			}
			is( $count, 1, "expected result count for quad with repeated variables (pass $pass)" );
			$plan->close;
		}
	}

	{
		my $var	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $plan	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				like( $row->{p}, qr#^(_:|<http://kasei.us)#, 'expected person URI or blank node' );
				like( $row->{page}, qr#^<http://(www.)?(kasei|realify)#, 'expected person homepage' );
				$count++;
			}
			is( $count, 2, "expected result count for nestedloop join (pass $pass)" );
			$plan->close;
		}
	}

	{
		my $var		= RDF::Trine::Node::Variable->new('s');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->PersonalProfileDocument );
		my $plan	= RDF::Query::Plan::Union->new( $plan_a, $plan_b );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				$count++;
			}
			is( $count, 5, "expected result count for union (pass $pass)" );
			$plan->close;
		}
	}

	{
		my $plan	= RDF::Query::Plan::Service->new( 'http://kasei.us/sparql', 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT DISTINCT * WHERE { ?p a foaf:Person ; foaf:homepage ?page }' );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				$count++;
			}
			is( $count, 19, "expected result count for SERVICE (pass $pass)" );
			$plan->close;
		}
	}

	{
		# project on ?p { ?s ?p foaf:Person }
		my $s	= RDF::Trine::Node::Variable->new('s');
		my $p	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $p, $foaf->Person );
		my $plan	= RDF::Query::Plan::Project->new( $plan_a, ['p'] );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				my @keys	= $row->variables;
				is_deeply( \@keys, ['p'], 'projected variable list' );
				$count++;
			}
			is( $count, 4, "expected result count for project (pass $pass)" );
			$plan->close;
		}
	}
	
	{
		# { _:s rdf:first [] ; ?p [] }
		my $s	= RDF::Trine::Node::Blank->new('s');
		my $f	= RDF::Trine::Node::Blank->new('f');
		my $r	= RDF::Trine::Node::Blank->new('r');
		my $p	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $rdf->first, $f );
		my $plan_b	= RDF::Query::Plan::Triple->new( $s, $p, $r );
		my $join	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		my $proj	= RDF::Query::Plan::Project->new( $join, ['p'] );
		my $plan	= RDF::Query::Plan::Distinct->new( $proj );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				like( $row->{p}, qr[^(<http://www.w3.org/1999/02/22-rdf-syntax-ns#(first|rest))>$], 'expected predicate URI' );
				$count++;
			}
			is( $count, 2, "expected result count for distinct (pass $pass)" );
			$plan->close;
		}
	}
	
	{
		# offset: { _:s a ?type }
		my $s		= RDF::Trine::Node::Blank->new('s');
		my $var		= RDF::Trine::Node::Variable->new('type');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $rdf->type, $var );
		my $proj	= RDF::Query::Plan::Project->new( $plan_a, ['type'] );
		my $dist	= RDF::Query::Plan::Distinct->new( $proj );
		my $plan	= RDF::Query::Plan::Offset->new( $dist, 2 );
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			while (my $row = $plan->next) {
				isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
				like( $row->{type}, qr[(Property|Person|PersonalProfileDocument)>$], 'expected predicate URI' );
				$count++;
			}
			is( $count, 1, "expected result count for offset (pass $pass)" );
			$plan->close;
		}
	}
}
