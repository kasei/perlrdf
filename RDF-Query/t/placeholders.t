#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More;
use Data::Dumper;

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		my $query	= RDF::Query->new(<<"END");
			SELECT * WHERE { ?s ?p ?o }
END
		isa_ok( $query, 'RDF::Query' );
		{
			my ($plan, $ctx)	= $query->prepare($model);
			my $iter	= $query->execute_plan($plan, $ctx);
			my $count	= 0;
			while (my $r = $iter->next) {
				$count++;
			}
			is($count, 70, 'expected triples count');
		}
		
		{
			my ($plan, $ctx)	= $query->prepare($model);
			my $term	= RDF::Query::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
			$ctx->bind_variable('s', $term);
			my $iter	= $query->execute_plan($plan, $ctx);
			my $count	= 0;
			while (my $r = $iter->next) {
				$count++;
			}
			is($count, 23, 'expected triples count after binding subject');
		}
		
		{
			my ($plan, $ctx)	= $query->prepare($model);
			my $term	= RDF::Query::Node::Resource->new('http://xmlns.com/foaf/0.1/knows');
			$ctx->bind_variable('p', $term);
			my $iter	= $query->execute_plan($plan, $ctx);
			my $count	= 0;
			while (my $r = $iter->next) {
				$count++;
			}
			is($count, 3, 'expected triples count after binding subject and object');
		}
		
		
		
	}
}

done_testing();
