use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

use RDF::Query;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.filter          = TRACE, Screen
# 	log4perl.category.rdf.query.functions.exists     = TRACE, Screen
# 	log4perl.category.rdf.query.plan.basicgraphpattern          = TRACE, Screen
# 	log4perl.category.rdf.query.plan.triple          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my @files	= map { "data/$_" } qw(foaf.xrdf);
my @models	= test_models( @files );
my $tests	= (scalar(@models) * 11);
plan tests => $tests;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT *
			WHERE {
				?p a foaf:Person ; foaf:name ?name .
				FILTER( NOT EXISTS {
					?p foaf:mbox_sha1sum "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" .
				} ).
			}
END
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			isa_ok( $row->{p}, 'RDF::Trine::Node', 'got person node' );
			isa_ok( $row->{name}, 'RDF::Trine::Node::Literal', 'got person name' );
			like( $row->{name}->literal_value, qr/^(Gary|Lauren|Liz)/, 'expected person name' );
		}
		is( $count, 3, 'expected result count with negation' );
	}
}
