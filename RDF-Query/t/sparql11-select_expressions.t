use strict;
use warnings;
no warnings 'redefine';
use Test::More;

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

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );
my $tests	= (scalar(@models) * 20);
plan tests => $tests;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT ?list (xsd:integer(?value) AS ?v)
			WHERE {
				?list rdf:first ?value ; rdf:rest rdf:nil .
			}
END
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			isa_ok( $row->{list}, 'RDF::Trine::Node' );
		}
		is( $count, 1, 'expected result count with select expression' );
	}

	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT (xsd:string(?homepage) AS ?page)
			WHERE {
				?p a foaf:Person ; foaf:firstName ?name ; foaf:homepage ?homepage .
			}
			ORDER BY ASC(?name)
END
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		my $count	= 0;
		my @expect	= qw(http://www.realify.com/~gary/ http://kasei.us/);
		while (my $row = $stream->next) {
			$count++;
			use Data::Dumper;
			my $page	= $row->{page};
			is_deeply([$row->variables], [qw(page)], 'expected variable list after projection');
			isa_ok( $page, 'RDF::Trine::Node::Literal', 'expected literal cast from a resource' );
			is( $page->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', 'expected xsd:string datatype' );
			is( $page->literal_value, shift(@expect), 'expected literal value in ASC order' );
		}
		is( $count, 2, 'expected result count with select expression and ASC order' );
	}

	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT (xsd:string(?homepage) AS ?page)
			WHERE {
				?p a foaf:Person ; foaf:firstName ?name ; foaf:homepage ?homepage .
			}
			ORDER BY DESC(?name)
END
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		my $count	= 0;
		my @expect	= qw(http://kasei.us/ http://www.realify.com/~gary/);
		while (my $row = $stream->next) {
			$count++;
			use Data::Dumper;
			my $page	= $row->{page};
			is_deeply([$row->variables], [qw(page)], 'expected variable list after projection');
			isa_ok( $page, 'RDF::Trine::Node::Literal', 'expected literal cast from a resource' );
			is( $page->literal_datatype, 'http://www.w3.org/2001/XMLSchema#string', 'expected xsd:string datatype' );
			is( $page->literal_value, shift(@expect), 'expected literal value in DESC order' );
		}
		is( $count, 2, 'expected result count with select expression and DESC order' );
	}
}
