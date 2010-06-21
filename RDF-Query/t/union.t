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
my $tests	= (scalar(@models) * 40);
plan tests => $tests;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT ?thing ?name
			WHERE	{
						{ ?thing a foaf:Person; foaf:name ?name }
						UNION
						{ ?thing a geo:Point; foaf:name ?name }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my ($thing, $name)	= @{ $row }{qw(thing name)};
			like( $thing->as_string, qr/^[<(]/, 'union person|point' );
			ok( $thing->isa('RDF::Trine::Node'), 'node: ' . $thing->as_string );
			ok( $name->isa('RDF::Trine::Node::Literal'), 'name: ' . $name->as_string );
		}
		is( $count, 6, 'expected result count' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT DISTINCT ?thing ?name
			WHERE	{
						{ ?thing a foaf:Person; foaf:name ?name }
						UNION
						{ ?thing a geo:Point; foaf:name ?name }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my ($thing, $name)	= @{ $row }{qw(thing name)};
			like( $thing->as_string, qr/^[<(]/, 'union person|point' );
			ok( $thing->isa('RDF::Trine::Node'), 'node: ' . $thing->as_string );
			ok( $name->isa('RDF::Trine::Node::Literal'), 'name: ' . $name->as_string );
		}
		is( $count, 6, 'expected distinct result count' );
	}
}
