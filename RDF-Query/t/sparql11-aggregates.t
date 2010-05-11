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

my @files	= map { "data/$_" } qw(t-sparql11-aggregates-1.rdf);
my @models	= test_models( @files );
my $tests	= (scalar(@models) * 30);
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
}
