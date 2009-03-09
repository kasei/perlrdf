#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.not		= DEBUG, Screen
# 	log4perl.appender.Screen					= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr				= 0
# 	log4perl.appender.Screen.layout				= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => 1 + (5 * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	{
		print "# not block\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT ?name
			WHERE {
				{ ?p a foaf:Person ; foaf:name ?name } UNSAID { ?p foaf:nick ?nick }
			}
END
		isa_ok( $query, 'RDF::Query' );
		my ($p,$c)	= $query->prepare( $model );
		my $iter	= $query->execute_plan( $p, $c );
		while (my $r = $iter->next) {
			my $name	= $r->{name};
			isa_ok( $name, 'RDF::Query::Node::Literal' );
			like( $name->literal_value, qr/^L/, 'expected name' );
		}
	}
}
