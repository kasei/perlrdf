#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use URI::file;
use Scalar::Util qw(blessed);
use RDF::Trine qw(literal);

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
use Test::Exception;
plan tests => (58 * scalar(@models));

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";
	
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
			ok( blessed($count) and $count->is_literal, 'literal aggregate' );
			is( $count->literal_value, 3, 'foaf:knows count' );
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
			ok( blessed($wide) and $wide->is_literal, 'literal aggregate' );
			ok( blessed($narrow) and $narrow->is_literal, 'literal aggregate' );
			is( $wide->literal_value, 4.5, 'wide (MIN) aperture' );
			is( $narrow->literal_value, 11, 'narrow (MAX) aperture' );
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
			ok( blessed($begin) and $begin->is_literal, 'literal aggregate' );
			ok( blessed($end) and $end->is_literal, 'literal aggregate' );
			is( $begin->literal_value, '2004-09-06T15:19:20+01:00', 'beginning date of photos' );
			is( $end->literal_value, '2005-04-07T18:27:56-04:00', 'ending date of photos' );
			$count++;
		}
		is( $count, 1, 'one aggreate' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT COUNT(?aperture)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'COUNT(?aperture)' => literal('4', undef, 'http://www.w3.org/2001/XMLSchema#integer') });
			is_deeply( $row, $expect, 'value for count apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT COUNT(DISTINCT ?aperture)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'COUNT(DISTINCT ?aperture)' => literal('2', undef, 'http://www.w3.org/2001/XMLSchema#integer') });
			is_deeply( $row, $expect, 'value for count distinct apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT MIN(?mbox)
			WHERE {
				[ a foaf:Person ; foaf:mbox_sha1sum ?mbox ]
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ 'MIN(?mbox)' => literal('19fc9d0234848371668cf10a1b71ac9bd4236806') });
			is_deeply( $row, $expect, 'value for min mbox_sha1sum' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
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
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ count => RDF::Query::Node::Literal->new('3', undef, 'http://www.w3.org/2001/XMLSchema#integer') });
			is_deeply( $row, $expect, 'COUNT() on sometimes unbound variable' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
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
		my $count	= 0;
		
		my %expect	= ( 'Gregory Todd Williams' => 2, 'Gary P' => 1 );
		while (my $row = $stream->next) {
			my $name	= $row->{name}->literal_value;
			my $expect	= $expect{ $name };
			cmp_ok( $row->{count}->literal_value, '==', $expect, 'expected COUNT() value for variable GROUP' );
			$count++;
		}
		is( $count, 2, 'two aggreate groups' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			SELECT AVG(?f)
			WHERE {
				?image exif:fNumber ?f
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $value	= (values %$row)[0];
			isa_ok( $value, 'RDF::Query::Node::Literal' );
			ok( $value->is_numeric_type, 'avg produces a numeric type' );
			is( $value->numeric_value, 6.125, 'expected average value' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			SELECT (MIN(?e) AS ?min) (MAX(?e) AS ?max)
			WHERE {
				[] foaf:mbox_sha1sum ?e
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $min	= $row->{min};
			my $max	= $row->{max};
			isa_ok( $min, 'RDF::Query::Node::Literal' );
			isa_ok( $max, 'RDF::Query::Node::Literal' );
			is( $min->literal_value, '19fc9d0234848371668cf10a1b71ac9bd4236806', 'expected MIN plain-literal' );
			is( $max->literal_value, 'f8677979059b73385c9d14cadf7d1e3652b205a8', 'expected MAX plain-literal' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT (MIN(?d) AS ?min) (MAX(?d) AS ?max)
			WHERE {
				[] dc:date ?d
			}
END
		isa_ok( $query, 'RDF::Query' );
		throws_ok {
			$query->execute( $model, strict_errors => 1 );
		} 'RDF::Query::Error::ComparisonError', 'expected comparision error on multi-typed values';
		
		# without strict errors, non-datatyped dates (in human readable form) will
		# be string-compared with dateTime-datatyped W3CDTF literals
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $min	= $row->{min};
			my $max	= $row->{max};
			isa_ok( $min, 'RDF::Query::Node::Literal' );
			isa_ok( $max, 'RDF::Query::Node::Literal' );
 			is( $min->literal_value, '2004-09-06T15:19:20+01:00', 'expected MIN plain-literal' );
 			is( $max->literal_value, 'Sat, 4 Oct 2003 20:02:22 PDT-0700', 'expected MAX plain-literal' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT (GROUP_CONCAT(?d) AS ?dates)
			WHERE {
				[] dc:date ?d
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $dates	= $row->{dates};
			isa_ok( $dates, 'RDF::Query::Node::Literal' );
 			is( $dates->literal_value, '2004-09-06T15:19:20+01:00 2005-04-07T18:27:37-04:00 2005-04-07T18:27:50-04:00 2005-04-07T18:27:56-04:00 Sat, 4 Oct 2003 20:02:22 PDT-0700', 'expected GROUP_CONCAT plain-literal' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX dc: <http://purl.org/dc/elements/1.1/>
			SELECT (SAMPLE(?d) AS ?date)
			WHERE {
				[] dc:date ?d
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $date	= $row->{date};
			isa_ok( $date, 'RDF::Query::Node::Literal' );
 			is( $date->literal_value, '2004-09-06T15:19:20+01:00', 'expected SAMPLE plain-literal' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
}

# {
# 	# HAVING tests
# 	my $model	= RDF::Trine::Model->temporary_model;
# 	my $data	= <<'END';
# @prefix : <http://books.example/> .
# 
# :org1 :affiliates :auth1, :auth2 .
# :org2 :affiliates :auth3 .
# 
# :auth1 :writesBook :book1, :book2 .
# :auth2 :writesBook :book3 .
# :auth3 :writesBook :book4 .
# 
# :book1 :price 9 .
# :book2 :price 5 .
# :book3 :price 7 .
# :book4 :price 7 .
# 
# END
# 	my $parser	= RDF::Trine::Parser->new('turtle');
# 	$parser->parse_into_model( 'http://base/', $data, $model );
# 	my $query	= RDF::Query->new( <<'END', { lang => 'sparql11' } );
# PREFIX : <http://books.example/>
# SELECT (SUM(?lprice) AS ?totalPrice)
# WHERE {
#   ?org :affiliates ?auth .
#   ?auth :writesBook ?book .
#   ?book :price ?lprice .
# }
# GROUP BY ?org
# HAVING (SUM(?lprice) > 10)
# END
# 
# ##############################
# # GROUPS:
# # org	auth	book	lprice
# # ----------------------------
# # org1	auth1	book1	9
# # org1	auth1	book2	5
# # org1	auth2	book3	7
# # ----------------------------
# # org2	auth3	book4	7
# # ----------------------------
# ##############################
# # AGGREGATES:
# # org	SUM(lprice)
# # ----------------------------
# # org1	21
# # ----------------------------
# # org2	7
# # ----------------------------
# ##############################
# # CONSTRAINTS:
# # org	SUM(lprice)
# # ----------------------------
# # org1	21
# # ----------------------------
# ##############################
# 
# 	warn RDF::Query->error unless ($query);
# 	my $iter	= $query->execute( $model );
# 	while (my $r = $iter->next) {
# 		use Data::Dumper;
# 		warn Dumper($r);
# 	}
# }
