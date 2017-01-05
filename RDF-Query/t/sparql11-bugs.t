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

{
	# GitHub issue #134: RDF::Query: FILTER accidently moved into SERVICE
	# <https://github.com/kasei/perlrdf/issues/134>
	#
	# The SPARQL Parser wasn't properly setting up a new scope for collecting
	# filters in parsing SERVICE patterns with IRI endpoints.
	
	my $query	= RDF::Query->new(<<'END');
PREFIX bd: <http://www.bigdata.com/rdf#>
PREFIX wikibase: <http://wikiba.se/ontology#>
SELECT * WHERE {
    <http://www.wikidata.org/entity/Q1> ?p ?o .
    FILTER regex(?o,'^[0-9]+$') .
    SERVICE wikibase:label {
        bd:serviceParam wikibase:language "en" .
    }
}
END
	my $algebra	= $query->pattern;
	isa_ok($algebra, 'RDF::Query::Algebra::Project');
	my $ggp		= $algebra->pattern;
	isa_ok($ggp, 'RDF::Query::Algebra::GroupGraphPattern');
	my @patterns	= $ggp->patterns;
	is(scalar(@patterns), 2);
	isa_ok($patterns[0], 'RDF::Query::Algebra::Filter');
	isa_ok($patterns[1], 'RDF::Query::Algebra::Service');
}

{
	# GitHub issue #135: RDF::Query: broken local name if prefixes overlap
	# <https://github.com/kasei/perlrdf/issues/135>
	
	my $query	= RDF::Query->new(<<'END');
PREFIX p: <http://www.wikidata.org/prop/>
PREFIX ps: <http://www.wikidata.org/prop/statement/>
SELECT * WHERE {
    ?id p:P1549 ?statement .
    ?statement ps:P1549 ?label .
}
END
	my $sparql	= $query->as_sparql;
	like($sparql, qr/ps:P1549/, 'SPARQL serialization of prefixedname containing a namespaced prefix');
}

done_testing();
