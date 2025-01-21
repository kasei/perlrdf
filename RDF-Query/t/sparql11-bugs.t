use strict;
use warnings;
no warnings 'redefine';
use Test::More;
use Test::Exception;
use Scalar::Util qw(blessed);
use RDF::Trine qw(literal);

use lib qw(. t);
require "models.pl";

use RDF::Query;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.exists          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

{
	my $sparql	= <<"END";
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX oup: <http://oxfordindex.oup.com/metadata/>
SELECT DISTINCT ?auth1 ?auth2
WHERE{
          ?auth1 oup:hasLink ?link1, ?link2.
          ?link1 a oup:isPrimaryTopicOfLink.
          FILTER (!sameTerm(?link1, ?link2))
          ?link1 oup:hasTarget ?CR1.
          ?CR1 (^oup:hasTarget) ?link3, ?link4.
          ?link3 a oup:referencesLink.
          ?link4 a oup:referencesLink.
          FILTER (!sameTerm(?link3, ?link4))
          ?link3 (^oup:hasLink) ?CR2.
          ?link4 (^oup:hasLink) ?CR3.
          ?auth2 oup:hasLink ?link5, ?link6.
          ?link5 a oup:isPrimaryTopicOfLink.
          ?link6 a oup:isPrimaryTopicOfLink.
          ?link5 oup:hasTarget ?CR2.
          ?link6 oup:hasTarget ?CR3.
} 
END
	my $query	= RDF::Query->new($sparql);
	isa_ok( $query, 'RDF::Query', 'https://github.com/kasei/perlrdf/issues/100' );
}

{
	my $model	= RDF::Trine::Model->new();
	my $query	= RDF::Query->new('PREFIX ex: <http://www.example.com/ns#> SELECT ?a WHERE { OPTIONAL { ?s ex:aggregate ?a } }');
	my $plan;
	lives_ok {
		($plan, my $ctx)	= $query->prepare($model);
	} 'Planning of optional plan (github issue 101)';
	isa_ok($plan, 'RDF::Query::Plan', 'Plan object from optional plan (github issue 101)');
}

done_testing();
