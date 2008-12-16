#!/usr/bin/perl
use strict;
use warnings;

use URI::file;
use Test::More;
use Data::Dumper;
use RDF::Query::Error qw(:try);

use lib qw(. t);
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.parser          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

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
} else {
	plan qw(no_plan); #tests => scalar(@models) * $model_tests + $nomodel_tests;
}

use RDF::Query;
use RDF::Trine::Namespace qw(rdf foaf);

use RDF::Query::Plan;

################################################################################

{
	{
		my $var		= RDF::Trine::Node::Variable->new('s');
		my $triple	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
		my $plan	= RDF::Query::Plan::Limit->new( 2, $triple );
		is( _CLEAN_WS($plan->sse), '(limit 2 (triple ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>))' ) or die;
	}

	{
		my $var		= RDF::Trine::Node::Variable->new('s');
		my $triple	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
		my $plan	= RDF::Query::Plan::Offset->new( 2, $triple );
		is( _CLEAN_WS($plan->sse), '(offset 2 (triple ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>))' ) or die;
	}

	{
		my $var	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $plan	= RDF::Query::Plan::ThresholdUnion->new( $plan_a, $plan_b );
		is( _CLEAN_WS($plan->sse), '(threshold-union (triple ?p <http://xmlns.com/foaf/0.1/homepage> ?page) (triple ?p <http://xmlns.com/foaf/0.1/name> ?name))', 'sse: threshold-union' ) or die;
	}

	{
		my $var	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
		my $subplan	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		my $plan	= RDF::Query::Plan::Service->new( 'http://kasei.us/sparql', $subplan, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT DISTINCT * WHERE { ?p a foaf:Person ; foaf:homepage ?page }' );
		is( _CLEAN_WS($plan->sse), '(service <http://kasei.us/sparql> "PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT DISTINCT * WHERE { ?p a foaf:Person ; foaf:homepage ?page }")', 'sse: service' ) or die;
	}
}

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
		my $query	= RDF::Query->new( <<"END", { lang => 'sparqlp' } );
PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?p ?name WHERE { ?p foaf:firstName ?name . } BINDINGS ?name { ("Gregory") ("Gary") }
END
		my ($plan, $context)	= $query->prepare();
		is( _CLEAN_WS($plan->sse), '(project (p name) (bind-join (triple ?p <http://xmlns.com/foaf/0.1/firstName> ?name) (table (row [?name "Gregory"]) (row [?name "Gary"]))))', 'sse: constant' ) or die;
	}
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
		my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person }', undef, $ns)->patterns;
		my ($t)		= $bgp->triples;
		my ($plan)	= RDF::Query::Plan->generate_plans( $t, $context );
		isa_ok( $plan, 'RDF::Query::Plan::Triple', 'triple algebra to plan' );
		is( $plan->sse, '(triple ?p <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>)', 'sse: triple plan' ) or die;
	}
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
		my ($bgp)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:name ?name }', undef, $ns)->patterns;
		my ($plan)	= RDF::Query::Plan->generate_plans( $bgp, $context );
# 		if ($bridge->supports('basic_graph_pattern')) {
# 			isa_ok( $plan, 'RDF::Query::Plan::BasicGraphPattern', 'triple algebra to plan' );
# 		} else {
			isa_ok( $plan, 'RDF::Query::Plan::Join', 'bgp algebra to plan' );
			isa_ok( $plan->lhs, 'RDF::Query::Plan::Triple', 'triple algebra to plan' );
			isa_ok( $plan->rhs, 'RDF::Query::Plan::Triple', 'triple algebra to plan' );
# 		}
	}
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $parsed	= $parser->parse( 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT * WHERE { ?p foaf:name ?name }' );
		my $algebra	= $parsed->{triples}[0]->pattern;
		my ($plan)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		isa_ok( $plan, 'RDF::Query::Plan::Triple', 'ggp algebra to plan' );
	}
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $parsed	= $parser->parse( 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT * WHERE { ?p foaf:name ?name } ORDER BY ?name' );
		my $algebra	= $parsed->{triples}[0]->pattern;
		my ($plan)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		isa_ok( $plan, 'RDF::Query::Plan::Sort', 'sort algebra to plan' );
		isa_ok( $plan->pattern, 'RDF::Query::Plan::Triple', 'triple algebra to plan' );
		is( _CLEAN_WS($plan->sse), '(order (triple ?p <http://xmlns.com/foaf/0.1/name> ?name) ((asc ?name)))', 'sse: sort' ) or die;
	}
	
	{
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $parsed	= $parser->parse( 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT * WHERE { ?p a foaf:Person ; foaf:name ?name . FILTER(?name = "Greg") }' );
		my $algebra	= $parsed->{triples}[0]->pattern;
		my ($plan)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		isa_ok( $plan, 'RDF::Query::Plan::Filter', 'filter algebra to plan' );
# 		if ($bridge->supports('basic_graph_pattern')) {
# 			isa_ok( $plan->pattern, 'RDF::Query::Plan::BasicGraphPattern', 'bgp algebra to plan' );
# 		} else {
			isa_ok( $plan->pattern, 'RDF::Query::Plan::Join', 'bgp algebra to plan' );
# 		}
		is( _CLEAN_WS($plan->sse), '(filter (== ?name "Greg") (nestedloop-join (triple ?p <http://xmlns.com/foaf/0.1/name> ?name) (triple ?p <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>)))', 'sse: filter' ) or die;
	}
	
	############################################################################
	
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
		is( _CLEAN_WS($plan->sse), '(quad ?p <http://xmlns.com/foaf/0.1/name> ?name ?c)', 'sse: quad' ) or die;
		
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
		# simple quad converted from algebra
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $parsed	= $parser->parse( 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT * WHERE { GRAPH ?c { ?p foaf:name ?name } }' );
		my $algebra	= $parsed->{triples}[0];
		my ($plan)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		
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
		# nested loop join
		my $var	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $plan	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		is( _CLEAN_WS($plan->sse), '(nestedloop-join (triple ?p <http://xmlns.com/foaf/0.1/homepage> ?page) (triple ?p <http://xmlns.com/foaf/0.1/name> ?name))', 'sse: nestedloop-join' ) or die;
		
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
		# OPTIONAL nested loop join
		my $var	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
		my $plan	= RDF::Query::Plan::Join::PushDownNestedLoop->new( $plan_a, $plan_b, 1 );
		is( _CLEAN_WS($plan->sse), '(bind-leftjoin (triple ?p <http://xmlns.com/foaf/0.1/name> ?name) (triple ?p <http://xmlns.com/foaf/0.1/homepage> ?page))', 'sse: bind-leftjoin' ) or die;
		
		foreach my $pass (1..2) {
			my $count	= 0;
			$plan->execute( $context );
			my @rows	= $plan->get_all;
			my @names	= map { $_->literal_value } grep { defined($_) } map { $_->{name} } @rows;
			my @pages	= map { $_->uri_value } grep { defined($_) } map { $_->{page} } @rows;
			is( scalar(@names), 4, 'expected result count for names in OPTIONAL join' );
			is( scalar(@pages), 2, 'expected result count for homepages in OPTIONAL join' );
			$plan->close;
		}
	}

	{
		# union
		my $var		= RDF::Trine::Node::Variable->new('s');
		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->PersonalProfileDocument );
		my $plan	= RDF::Query::Plan::Union->new( $plan_a, $plan_b );
		is( _CLEAN_WS($plan->sse), '(union (triple ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person>) (triple ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/PersonalProfileDocument>))' ) or die;
		
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
	
# 	SKIP: {
# 		skip "network tests. Set RDFQUERY_NETWORK_TESTS to run these tests.", 2 unless (exists $ENV{RDFQUERY_NETWORK_TESTS});
# 
# 		my $var	= RDF::Trine::Node::Variable->new('p');
# 		my $plan_a	= RDF::Query::Plan::Triple->new( $var, $rdf->type, $foaf->Person );
# 		my $plan_b	= RDF::Query::Plan::Triple->new( $var, $foaf->homepage, RDF::Trine::Node::Variable->new('page') );
# 		my $subplan	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
# 		my $plan	= RDF::Query::Plan::Service->new( 'http://kasei.us/sparql', $subplan, 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT DISTINCT * WHERE { ?p a foaf:Person ; foaf:homepage ?page }' );
# 		
# 		foreach my $pass (1..2) {
# 			my $count	= 0;
# 			$plan->execute( $context );
# 			while (my $row = $plan->next) {
# 				if ($count == 0) {
# 					isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
# 				}
# 				$count++;
# 			}
# 			cmp_ok( $count, '>', 1, "positive result count for SERVICE plan (pass $pass)" );
# 			$plan->close;
# 		}
# 	}

	SKIP: {
		skip "network tests. Set RDFQUERY_NETWORK_TESTS to run these tests.", 2 unless (exists $ENV{RDFQUERY_NETWORK_TESTS});
		my $parser	= RDF::Query::Parser::SPARQLP->new();
		my $parsed	= $parser->parse( 'PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT * WHERE { SERVICE <http://kasei.us/sparql> { ?p a foaf:Person ; foaf:homepage ?page } }' );
		my $algebra	= $parsed->{triples}[0];
		my ($plan)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		
		foreach my $pass (1..2) {
			my $skip	= 2;
			my $count	= 0;
			try {
				$plan->execute( $context );
				while (my $row = $plan->next) {
					if ($count == 0) {
						isa_ok( $row, 'RDF::Query::VariableBindings', 'variable bindings' );
					}
					$count++;
				}
				cmp_ok( $count, '>', 1, "positive result count for generated SERVICE plan (pass $pass)" );
				$plan->close;
				$skip--;
			} catch RDF::Query::Error::ExecutionError with {
				my $e	= shift;
				skip $e->text, $skip;
			};
		}
	}

	{
		# project on ?p { ?s ?p foaf:Person }
		my $s	= RDF::Trine::Node::Variable->new('s');
		my $p	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $p, $foaf->Person );
		my $plan	= RDF::Query::Plan::Project->new( $plan_a, ['p'] );
		is( _CLEAN_WS($plan->sse), '(project (p) (triple ?s ?p <http://xmlns.com/foaf/0.1/Person>))', 'sse: project' ) or die;
		
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
		my $s	= RDF::Trine::Node::Variable->new('__s');
		my $f	= RDF::Trine::Node::Variable->new('__f');
		my $r	= RDF::Trine::Node::Variable->new('__r');
		my $p	= RDF::Trine::Node::Variable->new('p');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $rdf->first, $f );
		my $plan_b	= RDF::Query::Plan::Triple->new( $s, $p, $r );
		my $join	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		my $proj	= RDF::Query::Plan::Project->new( $join, ['p'] );
		my $plan	= RDF::Query::Plan::Distinct->new( $proj );
		is( _CLEAN_WS($plan->sse), '(distinct (project (p) (nestedloop-join (triple ?__s <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> ?__f) (triple ?__s ?p ?__r))))', 'sse: distinct-project-join' ) or die;

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
		# simple variable sort with numerics
		my $s		= RDF::Trine::Node::Variable->new('__s');
		my $var		= RDF::Trine::Node::Variable->new('v');
		my $triple	= RDF::Query::Plan::Triple->new( $s, $rdf->first, $var );
		my $proj	= RDF::Query::Plan::Project->new( $triple, ['v'] );
		
		foreach my $data ([0 => [1,2,3]], [1 => [3,2,1]]) {
			my ($order, $expect)	= @$data;
			my $dir		= ($order) ? 'DESC' : 'ASC';
			my $plan	= RDF::Query::Plan::Sort->new( $proj, [$var, $order] );
			my $count	= 0;
			$plan->execute( $context );
			my @rows	= $plan->get_all;
			my @values	= map { $_->{ v }->literal_value } @rows;
			is_deeply( \@values, $expect, "expected $dir sort values on numerics" );
			$plan->close;
		}
	}
	
	{
		# simple variable sort with plain literals
		my $s		= RDF::Trine::Node::Variable->new('__s');
		my $var		= RDF::Trine::Node::Variable->new('v');
		my $triple	= RDF::Query::Plan::Triple->new( $s, $foaf->name, $var );
		my $proj	= RDF::Query::Plan::Project->new( $triple, ['v'] );
		my $expr	= RDF::Query::Expression::Function->new( 'sparql:str', $var );
		
		my @expect	= ('Gary Peck', 'Gregory Todd Williams', 'Lauren Bradford', 'Liz Farrand Dubeck');
		foreach my $data ([0 => [@expect]], [1 => [reverse @expect]]) {
			my ($order, $expect)	= @$data;
			my $dir		= ($order) ? 'DESC' : 'ASC';
			my $plan	= RDF::Query::Plan::Sort->new( $proj, [$expr, $order] );
			my $count	= 0;
			$plan->execute( $context );
			my @rows	= $plan->get_all;
			my @values	= map { $_->{ v }->literal_value } @rows;
			is_deeply( \@values, $expect, "expected $dir sort values on plain literals" );
			$plan->close;
		}
	}
	
	{
		# sort with multiple expressions
		my $s		= RDF::Trine::Node::Variable->new('__s');
		my $s2		= RDF::Trine::Node::Variable->new('__s2');
		my $var		= RDF::Trine::Node::Variable->new('v');
		my $name	= RDF::Trine::Node::Variable->new('name');
		my $plan_a	= RDF::Query::Plan::Triple->new( $s, $rdf->first, $var );
		my $plan_b	= RDF::Query::Plan::Triple->new( $s2, $foaf->name, $name );
		my $join	= RDF::Query::Plan::Join::NestedLoop->new( $plan_a, $plan_b );
		my $proj	= RDF::Query::Plan::Project->new( $join, [qw(v name)] );
		my $expr1	= RDF::Query::Expression::Binary->new(
						'*',
						RDF::Query::Expression::Function->new( 'http://www.w3.org/2001/XMLSchema#integer', $var ),
						RDF::Query::Node::Literal->new('-1', undef, 'http://www.w3.org/2001/XMLSchema#integer')
					);
		my $expr2	= RDF::Query::Expression::Function->new( 'sparql:str', $name );
		my $plan	= RDF::Query::Plan::Sort->new( $proj, [$expr1, 0], [$expr2, 1] );
		
		my @expect_v	= (3,2,1);
		my @expect_name	= reverse('Gary Peck', 'Gregory Todd Williams', 'Lauren Bradford', 'Liz Farrand Dubeck');
		
		$plan->execute( $context );
		my @rows	= $plan->get_all;
		my @v		= map { $_->{ v }->literal_value } @rows;
		my @names	= map { $_->{ name }->literal_value } @rows;
		is_deeply( \@v, [map { ($_)x4 } @expect_v], "expected primary sort values on numerics" );
		is_deeply( \@names, [(@expect_name)x3], "expected secondary sort values on plain literals" );
		$plan->close;
	}
	
	{
		# filter
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
		my ($algebra)	= $parser->parse_pattern('{ ?p a foaf:Person ; foaf:firstName ?name . FILTER(?name = "Gregory") }', undef, $ns);
		my ($join)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		my $plan	= RDF::Query::Plan::Project->new( $join, [qw(name)] );
		
		$plan->execute( $context );
		my @rows	= $plan->get_all;
		my @v		= map { $_->{ name }->literal_value } @rows;
		is_deeply( \@v, ['Gregory'], "expected filtered values on literals" );
		$plan->close;
	}
	
	{
		# construct
		my $parser	= RDF::Query::Parser::SPARQL->new();
		my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
		my ($algebra)	= $parser->parse_pattern('{ ?p foaf:firstName ?name }', undef, $ns);
		my ($pat)	= RDF::Query::Plan->generate_plans( $algebra, $context );
		my $st		= RDF::Trine::Statement->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $plan	= RDF::Query::Plan::Construct->new( $pat, [ $st ] );
		is( _CLEAN_WS($plan->sse), '(construct (triple ?p <http://xmlns.com/foaf/0.1/firstName> ?name) ((triple ?p <http://xmlns.com/foaf/0.1/name> ?name)))', 'sse: construct' ) or die;
		
		$plan->execute( $context );
		my $count	= 0;
		while (my $row = $plan->next) {
			isa_ok( $row, 'RDF::Trine::Statement' );
			my $pred	= $row->predicate();
			my $obj		= $row->object();
			is( $pred->as_string, '<http://xmlns.com/foaf/0.1/name>', 'expected CONSTRUCT predicate' );
			like( $obj->as_string, qr<"(.+)">, 'expected CONSTRUCT object' );
			$count++;
		}
		is( $count, 4, 'expected CONSTRUCT triple count' );
		$plan->close;
	}
}



sub _CLEAN_WS {
	my $string	= shift;
	for ($string) {
		s/\s+/ /g;
	}
	return $string;
}
