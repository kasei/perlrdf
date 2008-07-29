use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

use RDF::Query;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.algebra.union          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= (scalar(@models) * 26);
plan tests => $tests;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT ?thing ?name
			WHERE	{
						{ ?thing a foaf:Person; foaf:name ?name }
						UNION
						{ ?thing a rdfs:Class; rdfs:label ?name }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $row = $stream->next) {
			my ($thing, $name)	= @{ $row }{qw(thing name)};
			like( $query->bridge->as_string( $thing ), qr/kasei|xmlns|[(]|_:/, 'union person|thing' );
			ok( $query->bridge->isa_node( $thing ), 'node: ' . $query->bridge->as_string( $thing ) );
			ok( $query->bridge->isa_literal( $name ), 'name: ' . $query->bridge->as_string( $name ) );
		}
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT	DISTINCT ?thing ?name
			WHERE	{
						{ ?thing a foaf:Person; foaf:name ?name }
						UNION
						{ ?thing a rdfs:Class; rdfs:label ?name }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $row = $stream->next) {
			my ($thing, $name)	= @{ $row }{qw(thing name)};
			like( $query->bridge->as_string( $thing ), qr/kasei|xmlns|[(]|_:/, 'union person|thing' );
			ok( $query->bridge->isa_node( $thing ), 'node: ' . $query->bridge->as_string( $thing ) );
			ok( $query->bridge->isa_literal( $name ), 'name: ' . $query->bridge->as_string( $name ) );
		}
	}
}
