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

my @files	= map { "data/$_" } qw(t-sparql11-aggregates-1.rdf foaf.xrdf about.xrdf);
my @models	= test_models( @files );
my $tests	= (scalar(@models) * 92);
plan tests => $tests;

foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		print "# SELECT SUM aggregate with GROUP BY and HAVING\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT (SUM(?lprice) AS ?totalPrice)
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?org
	HAVING (SUM(?lprice) > 10)
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my $tp	= $row->{totalPrice};
			isa_ok( $tp, 'RDF::Trine::Node::Literal', 'got ?totalPrice value' );
			is( $tp->literal_value, '21', 'expected literal value' );
			is( $tp->literal_datatype, 'http://www.w3.org/2001/XMLSchema#integer', 'expected integer datatype' );
		}
		is( $count, 1, 'expected result count with aggregation' );
	}

	{
		print "# SELECT GROUPED Variable with GROUP BY and HAVING\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT ?org
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?org
	HAVING (SUM(?lprice) > 10)
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			my $org	= $row->{org};
			isa_ok( $org, 'RDF::Trine::Node::Resource', 'got ?org value' );
		}
		is( $count, 1, 'expected result count with aggregation' );
	}

	{
		print "# SELECT MIN with GROUP BY\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT ?auth (MIN(?lprice) AS ?min)
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?auth
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		my %expect	= (
			'http://books.example/auth1'	=> 5,
			'http://books.example/auth2'	=> 7,
			'http://books.example/auth3'	=> 7,
		);
		while (my $row = $stream->next) {
			$count++;
			my $auth	= $row->{auth};
			my $val		= $row->{min};
			isa_ok( $auth, 'RDF::Trine::Node::Resource', 'got ?auth value' );
			isa_ok( $val, 'RDF::Trine::Node::Literal', 'got ?min value' );
			my $expect	= $expect{ $auth->uri_value };
			cmp_ok( $val->literal_value, '==', $expect, 'expected MIN value' );
		}
		is( $count, 3, 'expected result count with aggregation' );
	}

	{
		print "# SELECT MAX with GROUP BY\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT ?auth (MAX(?lprice) AS ?max)
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?auth
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		my %expect	= (
			'http://books.example/auth1'	=> 9,
			'http://books.example/auth2'	=> 7,
			'http://books.example/auth3'	=> 7,
		);
		while (my $row = $stream->next) {
			$count++;
			my $auth	= $row->{auth};
			my $val		= $row->{max};
			isa_ok( $auth, 'RDF::Trine::Node::Resource', 'got ?auth value' );
			isa_ok( $val, 'RDF::Trine::Node::Literal', 'got ?max value' );
			my $expect	= $expect{ $auth->uri_value };
			cmp_ok( $val->literal_value, '==', $expect, 'expected MAX value' );
		}
		is( $count, 3, 'expected result count with aggregation' );
	}

	{
		print "# SELECT MAX with GROUP BY and ORDER BY DESC\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT ?auth (MAX(?lprice) AS ?max)
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?auth
	ORDER BY DESC(?max)
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		my @expect	= (9, 7, 7);
		while (my $row = $stream->next) {
			$count++;
			my $val		= $row->{max};
			isa_ok( $val, 'RDF::Trine::Node::Literal', 'got ?max value' );
			my $expect	= shift(@expect);
			cmp_ok( $val->literal_value, '==', $expect, 'expected DESC MAX value' );
		}
		is( $count, 3, 'expected result count with aggregation' );
	}

	{
		print "# SELECT MAX with GROUP BY and ORDER BY ASC\n";
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11' } );
	PREFIX : <http://books.example/>
	SELECT ?auth (MAX(?lprice) AS ?max)
	WHERE {
	  ?org :affiliates ?auth .
	  ?auth :writesBook ?book .
	  ?book :price ?lprice .
	}
	GROUP BY ?auth
	ORDER BY ASC(?max)
END
		warn RDF::Query->error unless ($query);
		my ($plan, $ctx)	= $query->prepare( $model );
		my $pattern			= $query->pattern;
		my $stream	= $query->execute_plan( $plan, $ctx );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		my @expect	= (7, 7, 9);
		while (my $row = $stream->next) {
			$count++;
			my $val		= $row->{max};
			isa_ok( $val, 'RDF::Trine::Node::Literal', 'got ?max value' );
			my $expect	= shift(@expect);
			cmp_ok( $val->literal_value, '==', $expect, 'expected ASC MAX value' );
		}
		is( $count, 3, 'expected result count with aggregation' );
	}
	
	{
		print "# SELECT COUNT(VAR)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT (COUNT(?aperture) AS ?count)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' ) or warn RDF::Query->error;
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ count => literal('4', undef, 'http://www.w3.org/2001/XMLSchema#integer') });
			is_deeply( $row, $expect, 'value for count apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		print "# SELECT COUNT(DISTINCT VAR)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT (COUNT(DISTINCT ?aperture) AS ?count)
			WHERE {
				?image a foaf:Image ; exif:fNumber ?aperture
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ count => literal('2', undef, 'http://www.w3.org/2001/XMLSchema#integer') });
			is_deeply( $row, $expect, 'value for count distinct apertures' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		print "# SELECT MIN(STR)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT (MIN(?mbox) AS ?min)
			WHERE {
				[ a foaf:Person ; foaf:mbox_sha1sum ?mbox ]
			}
END
		isa_ok( $query, 'RDF::Query' );
		
		my $stream	= $query->execute( $model );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $expect	= RDF::Query::VariableBindings->new({ min => literal('19fc9d0234848371668cf10a1b71ac9bd4236806') });
			is_deeply( $row, $expect, 'value for min mbox_sha1sum' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		print "# SELECT COUNT(VAR)\n";
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
		print "# SELECT COUNT(VAR) with GROUP BY\n";
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
		print "# SELECT AVG(STR)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql11' );
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			SELECT (AVG(?f) AS ?avg)
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
		print "# SELECT MIN(STR), MAX(STR)\n";
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
		print "# SELECT MIN(STR), MAX(STR)\n";
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
		print "# SELECT GROUP_CONCAT(STR)\n";
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
			my $lit	= $dates->literal_value;
			like( $lit, qr/2004-09-06T15:19:20[+]01:00/, 'expected GROUP_CONCAT plain-literal' );
			like( $lit, qr/2005-04-07T18:27:37-04:00/, 'expected GROUP_CONCAT plain-literal' );
			like( $lit, qr/2005-04-07T18:27:50-04:00/, 'expected GROUP_CONCAT plain-literal' );
			like( $lit, qr/2005-04-07T18:27:56-04:00/, 'expected GROUP_CONCAT plain-literal' );
			like( $lit, qr/Sat, 4 Oct 2003 20:02:22 PDT-0700/, 'expected GROUP_CONCAT plain-literal' );
			$count++;
		}
		is( $count, 1, 'one aggreate row' );
	}
	
	{
		print "# SELECT SAMPLE(STR)\n";
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
