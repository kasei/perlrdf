#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Data::Dumper;
use Test::More qw(no_plan); #tests => 36;
use Test::Exception;
use Scalar::Util qw(reftype blessed);
use RDF::Query;

use lib qw(. t);
BEGIN { require "models.pl"; }


################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.costmodel		= DEBUG, Screen
# 	log4perl.appender.Screen					= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr				= 0
# 	log4perl.appender.Screen.layout				= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models_and_classes( @files );

foreach my $data (@models) {
	my $bridge	= $data->{bridge};
	my $model	= $data->{modelobj};
	next unless ($bridge->supports('node_counts'));
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
	
	{
		my $count	= $bridge->count_statements();
		is( $count, 70, 'count()' );
	}
	
	{
		my $count	= $bridge->count_statements( undef, $foaf->schoolHomepage, undef );
		is( $count, 8, 'count(,foaf:schoolHomepage,)' );
	}
	
	{
		my $freq	= $bridge->node_count( undef, $foaf->schoolHomepage, undef );
		is( $freq, (8/70), 'node frequency (,foaf:schoolHomepage,)' );
	}
	
	{
		my $samo	= RDF::Trine::Node::Resource->new('http://www.samohi.smmusd.org/');
		my $freq	= $bridge->node_count( undef, undef, $samo );
		is( $freq, (4/70), 'node frequency (,,samo)' );
	}
	
	{
		{
			my $context	= RDF::Query::ExecutionContext->new(
							bound		=> {},
							model		=> $bridge,
							costmodel	=> RDF::Query::CostModel::Counted->new(),
							optimize	=> 1,
						);
			my $parser	= RDF::Query::Parser::SPARQL->new();
			my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
			my ($algebra)	= $parser->parse_pattern('{ ?p foaf:mbox_sha1sum ?mbox ; foaf:schoolHomepage ?homepage }', undef, $ns);
			my ($join)	= RDF::Query::Plan->generate_plans( $algebra, $context );
			my $lhs		= $join->lhs;
			isa_ok( $lhs, 'RDF::Query::Plan::Triple' );
			my @nodes	= $lhs->nodes;
			my $pred	= $nodes[1];
			isa_ok( $pred, 'RDF::Query::Node::Resource' );
			is( $pred->uri_value, 'http://xmlns.com/foaf/0.1/mbox_sha1sum', 'expected join LHS with optimization' );
		}

		{
			my $context	= RDF::Query::ExecutionContext->new(
							bound		=> {},
							model		=> $bridge,
							costmodel	=> RDF::Query::CostModel::Counted->new(),
							optimize	=> 0,
						);
			my $parser	= RDF::Query::Parser::SPARQL->new();
			my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/' };
			my ($algebra)	= $parser->parse_pattern('{ ?p foaf:mbox_sha1sum "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ; foaf:schoolHomepage ?homepage }', undef, $ns);
			my ($join)	= RDF::Query::Plan->generate_plans( $algebra, $context );
			my $lhs		= $join->lhs;
			isa_ok( $lhs, 'RDF::Query::Plan::Triple' );
			my @nodes	= $lhs->nodes;
			my $pred	= $nodes[1];
			isa_ok( $pred, 'RDF::Query::Node::Resource' );
			is( $pred->uri_value, 'http://xmlns.com/foaf/0.1/schoolHomepage', 'expected join LHS without optimization' );
		}
	}
	
	{
		{
			my $context	= RDF::Query::ExecutionContext->new(
							bound		=> {},
							model		=> $bridge,
							costmodel	=> RDF::Query::CostModel::Counted->new(),
							optimize	=> 1,
						);
			my $parser	= RDF::Query::Parser::SPARQL->new();
			my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/', rdfs => 'http://www.w3.org/2000/01/rdf-schema#' };
			my ($algebra)	= $parser->parse_pattern(<<"END", undef, $ns);
{
	?p a foaf:Person ;
		foaf:nick ?nick ;
		foaf:schoolHomepage ?homepage ;
		rdfs:seeAlso ?seealso ;
}
END
			my ($join)	= RDF::Query::Plan->generate_plans( $algebra, $context );
			my $sse		= $join->sse;
			like( $sse, qr=seeAlso>.*nick>.*type>.*schoolHomepage>=, 'frequency-optimized BGP join ordering' );
		}

		{
			my $context	= RDF::Query::ExecutionContext->new(
							bound		=> {},
							model		=> $bridge,
							costmodel	=> RDF::Query::CostModel::Counted->new(),
							optimize	=> 0,
						);
			my $parser	= RDF::Query::Parser::SPARQL->new();
			my $ns		= { foaf => 'http://xmlns.com/foaf/0.1/', rdfs => 'http://www.w3.org/2000/01/rdf-schema#' };
			my ($algebra)	= $parser->parse_pattern(<<"END", undef, $ns);
{
	?p a foaf:Person ;
		foaf:nick ?nick ;
		foaf:schoolHomepage ?homepage ;
		rdfs:seeAlso ?seealso ;
}
END
			my ($join)	= RDF::Query::Plan->generate_plans( $algebra, $context );
			my $sse		= $join->sse;
			unlike( $sse, qr=seeAlso>.*nick>.*type>.*schoolHomepage>=, 'BGP join ordering without frequency-optimization' );
		}
	}
}
