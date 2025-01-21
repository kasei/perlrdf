#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use Scalar::Util qw(blessed);

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my $tests	= 7;
my @models	= test_models( qw(data/foaf.xrdf) );
plan tests => 1 + ($tests * scalar(@models));

use_ok( 'RDF::Query' );

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query	= TRACE, Screen
# 	log4perl.category.rdf.query.plan.computedstatement	= TRACE, Screen
# 	log4perl.category.rdf.query.plan.join.pushdownnestedloop	= TRACE, Screen
# 	log4perl.appender.Screen						= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr					= 0
# 	log4perl.appender.Screen.layout					= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	SKIP: {
		{
			print "# computed predicate: list:member\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
				PREFIX test: <http://kasei.us/e/ns/test#>
				PREFIX list: <http://www.jena.hpl.hp.com/ARQ/list#>
				SELECT ?member
				WHERE {
					?x test:mycollection ?list .
					?list list:member ?member .
				}
END
			$query->add_computed_statement_generator( 'http://www.jena.hpl.hp.com/ARQ/list#member' => \&__compute_list_member );
			my $count	= 0;
			
# 			warn $model->as_string;
#  			my ($plan, $ctx)	= $query->prepare( $model );
# 			warn $plan->explain();
# 			$query->execute_plan( $plan, $ctx );
			
			my $stream	= $query->execute( $model );
			my %expect	= map { $_ => 1 } (1,2,3);
			while (my $row = $stream->next) {
				isa_ok( $row->{member}, 'RDF::Query::Node::Literal' );
				my $value	= $row->{member}->literal_value;
				ok( exists($expect{ $value }), "got expected value $value");
				delete $expect{ $value };
			} continue { ++$count };
			is( $count, 3, 'expecting three list members' );
		}
	}
}




sub __compute_list_member {
	my $query	= shift;
	my $bound	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	my $c 		= shift;
	
	my $first	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' );
	my $rest	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' );
	
	my $model	= $query->model;
	if (blessed($p) and $p->isa('RDF::Query::Node::Resource') and $p->uri_value( 'http://www.jena.hpl.hp.com/ARQ/list#member' )) {
		my @lists;
		my $lists	= ($c)
					? $model->get_named_statements( $s, $first, $o, $c )
					: $model->get_statements( $s, $first, $o );
		while (my $l = $lists->next) {
			push(@lists, [$l, $l->subject]);
		}
		my %seen;
		my $sub		= sub {
# 			warn 'trying to compute list:member';
			my ($listst, $list, $head);
			while (1) {
				unless (scalar(@lists)) {
# 					warn "no more lists to check";
					return undef;
				}
				my $data	= shift(@lists);
				($listst, $head)	= @$data;
				$list	= $listst->subject;
				if ($seen{ $head->as_string, $list->as_string }++) {
# 					warn "already seen this list...";
					next;
				} else {
					last;
				}
			}
# 			warn "checking list " . $list->as_string;
			return undef if (blessed($list) and $list->isa('RDF::Query::Node::Resource') and $list->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
			my $obj		= $listst->object;
			my $tail	= ($c)
						? $model->get_named_statements( $list, $rest, undef, $c )
						: $model->get_statements( $list, $rest, undef );
			while (my $st = $tail->next) {
				my $lists	= ($c)
							? $model->get_named_statements( $st->object, $first, $o, $c )
							: $model->get_statements( $st->object, $first, $o );
				while (my $st = $lists->next) {
					push(@lists, [$st, $head]);
				}
			}
			
			my $newhead	= $head;
			my $st	= RDF::Query::Algebra::Triple->new( $head, RDF::Query::Node::Resource->new('http://www.jena.hpl.hp.com/ARQ/list#member'), $obj );
			return $st;
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	}
}
