#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
use RDF::Query;
BEGIN { require "models.pl"; }

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.project	= TRACE, Screen
# 	log4perl.category.rdf.query.plan.aggregate	= TRACE, Screen
# 	
# 	log4perl.appender.Screen					= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr				= 0
# 	log4perl.appender.Screen.layout				= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################


my @files	= map { "data/$_" } qw(foaf.xrdf about.xrdf);
my @models	= test_models( @files );

use Test::More;
plan tests => (36 * scalar(@models));

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	my $bridge	= RDF::Query->get_bridge( $model );
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?p ?knows
			WHERE {
				?p a foaf:Person ;
					foaf:knows ?knows .
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( [RDF::Query::Node::Variable->new('p')], count => ['COUNT', RDF::Query::Node::Variable->new('knows')] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my $count	= $row->{count};
			ok( $bridge->is_literal( $count ), 'literal aggregate' );
			is( $bridge->literal_value( $count ), 3, 'foaf:knows count' );
		}
		is( $count, 1, 'one aggreate' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?image ?aperture
			WHERE {
				?image a foaf:Image ;
					exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( [], wide => ['MIN', RDF::Query::Node::Variable->new('aperture')], narrow => ['MAX', RDF::Query::Node::Variable->new('aperture')] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $wide	= $row->{wide};
			my $narrow	= $row->{narrow};
			ok( $bridge->is_literal( $wide ), 'literal aggregate' );
			ok( $bridge->is_literal( $narrow ), 'literal aggregate' );
			is( $bridge->literal_value( $wide ), 4.5, 'wide (MIN) aperture' );
			is( $bridge->literal_value( $narrow ), 11, 'narrow (MAX) aperture' );
			$count++;
		}
		is( $count, 1, 'one aggreate' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END" );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			SELECT ?place ?date
			WHERE {
				[] a foaf:Image ;
					dcterms:spatial [ foaf:name ?place ] ;
					dc:date ?date .
				FILTER( DATATYPE(?date) = xsd:dateTime )
			}
			ORDER BY DESC(?place)
END
		isa_ok( $query, 'RDF::Query' );
		
		$query->aggregate( [], begin => ['MIN', RDF::Query::Node::Variable->new('date')], end => ['MAX', RDF::Query::Node::Variable->new('date')] );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		my @expect	= ( ['Providence, RI', ''] );
		while (my $row = $stream->next) {
			my $begin	= $row->{begin};
			my $end	= 	$row->{end};
			ok( $bridge->is_literal( $begin ), 'literal aggregate' );
			ok( $bridge->is_literal( $end ), 'literal aggregate' );
			is( $bridge->literal_value( $begin ), '2004-09-06T15:19:20+01:00', 'beginning date of photos' );
			is( $bridge->literal_value( $end ), '2005-04-07T18:27:56-04:00', 'ending date of photos' );
			$count++;
		}
		is( $count, 1, 'one aggreate' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT COUNT(?aperture)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'COUNT(?aperture)' => $bridge->new_literal('4', undef, 'http://www.w3.org/2001/XMLSchema#decimal') });
			is_deeply( $row, $expect, 'value for count apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT COUNT(DISTINCT ?aperture)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'COUNT(DISTINCT ?aperture)' => $bridge->new_literal('2', undef, 'http://www.w3.org/2001/XMLSchema#decimal') });
			is_deeply( $row, $expect, 'value for count distinct apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT MIN(?mbox)
			WHERE {
				[ a foaf:Person ; foaf:mbox_sha1sum ?mbox ]
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'MIN(?mbox)' => $bridge->new_literal('19fc9d0234848371668cf10a1b71ac9bd4236806') });
			is_deeply( $row, $expect, 'value for min mbox_sha1sum' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT (COUNT(?nick) AS ?count)
			WHERE {
				?p a foaf:Person .
				OPTIONAL {
					?p foaf:nick ?nick
				}
			}
END
		isa_ok( $query, 'RDF::Query' );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ count => RDF::Query::Node::Literal->new('3', undef, 'http://www.w3.org/2001/XMLSchema#decimal') });
			is_deeply( $row, $expect, 'COUNT() on sometimes unbound variable' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?name (COUNT(?nick) AS ?count)
			WHERE {
				?p a foaf:Person ;
					foaf:name ?name;
					foaf:nick ?nick .
			}
			GROUP BY ?name
END
		isa_ok( $query, 'RDF::Query' );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		
		my %expect	= ( 'Gregory Todd Williams' => 2, 'Gary Peck' => 1 );
		while (my $row = $stream->next) {
			use Data::Dumper;
			my $name	= $row->{name}->literal_value;
			my $expect	= $expect{ $name };
			cmp_ok( $row->{count}->literal_value, '==', $expect, 'expected COUNT() value for variable GROUP' );
			$count++;
		}
		is( $count, 2, 'two aggreate groups' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparqlp' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?fixedpoint (COUNT(*) AS ?count)
			WHERE {
				?image exif:fNumber ?f
			}
			GROUP BY (?f * 10 AS ?fixedpoint)
END
		isa_ok( $query, 'RDF::Query' );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		
		my %expect	= ( '45' => 3, '110' => 1 );
		while (my $row = $stream->next) {
			my $f		= $row->{fixedpoint}->literal_value;
			my $expect	= $expect{ $f };
			cmp_ok( $row->{count}->literal_value, '==', $expect, 'expected COUNT() value for expression GROUP' );
			$count++;
		}
		is( $count, 2, 'two aggreate groups' );
	}
	
}
