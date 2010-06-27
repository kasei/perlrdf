use Test::More tests => 32;
use strict;
use warnings;
use Data::Dumper;

# use lib qw(. t);
# BEGIN { require "models.pl"; }
# 
# my @files	= map { "data/$_" } qw(foaf.xrdf);
# my @models	= test_models( @files );

use RDF::Query;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.path          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my $model	= RDF::Trine::Model->temporary_model;
RDF::Query->new(<<"END", { update => 1 })->execute($model);
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA {
	<listpointer> <mylist> <list1> .
	<list1> rdf:first 1 ;
		rdf:rest <list2> .
	<list2> rdf:first 2 ;
		rdf:rest <list3> .
	<list3> rdf:first 3 ;
		rdf:rest rdf:nil .
}
END
RDF::Query->new(<<"END", { update => 1 })->execute($model);
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
INSERT DATA {
	<bob> foaf:name "Bob" .
	<alice> foaf:name "Alice" .
	<eve> foaf:knows <alice>, <bob> .
}
END

{
	print "# /-path\n";
	my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?name
		WHERE {
			?p foaf:knows/foaf:name ?name
		}
END
	my $count	= 0;
	my $iter	= $query->execute( $model );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	while (my $row = $iter->next) {
		isa_ok( $row->{name}, 'RDF::Query::Node::Literal' );
		like($row->{name}->literal_value, qr/Alice|Bob/, 'expected person name');
		$count++;
	}
	is( $count, 2, 'expected result count' );
}

{
	print "# rdf:List +-path\n";
	my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX test: <http://kasei.us/e/ns/test#>
		SELECT *
		WHERE {
			<listpointer> <mylist> ?list .
			?list rdf:rest+/rdf:first ?value .
		}
END
	my $count	= 0;
	my $iter	= $query->execute( $model );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my @got;
	while (my $row = $iter->next) {
		my $value	= $row->{value};
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		like($value->literal_value, qr/^[123]$/, 'expected list value');
		$got[ $value->literal_value - 1 ]	= $value->literal_value;
		$count++;
	}
	is_deeply( \@got, [undef, 2, 3], 'all expected values seen' );
}

{
	print "# rdf:List *-path\n";
	my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX test: <http://kasei.us/e/ns/test#>
		SELECT *
		WHERE {
			<listpointer> <mylist> ?list .
			?list rdf:rest*/rdf:first ?value .
		}
END
	my $count	= 0;
	my $iter	= $query->execute( $model );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my @got;
	while (my $row = $iter->next) {
		my $value	= $row->{value};
		isa_ok( $value, 'RDF::Query::Node::Literal' );
		like($value->literal_value, qr/^[123]$/, 'expected list value');
		$got[ $value->literal_value - 1 ]	= $value->literal_value;
		$count++;
	}
	is_deeply( \@got, [1, 2, 3], 'all expected values seen' );
}

{
	print "# property path in GRAPH\n";
	my $model	= RDF::Trine::Model->temporary_model;
	my $insert	= RDF::Query->new(<<"END", { update => 1 });
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		INSERT DATA {
			GRAPH <g1> {
				<eve> foaf:knows <alice>, <bob> .
				<alice> foaf:name "Alice" .
				<bob> foaf:name "Bob" .
			}
			GRAPH <g2> {
				_:x foaf:knows <eve> .
				<eve> foaf:name "Eve" .
			}
		}
END
	$insert->execute( $model );
	
	{
		my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT *
			WHERE {
				GRAPH <g1> {
					?p foaf:knows/foaf:name ?name .
				}
			}
END
		my $iter	= $query->execute( $model );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my @got;
		while (my $row = $iter->next) {
			like( $row->{name}, qr/Bob|Alice/, 'expected property path value restricted to graph' );
		}
		is( $iter->count, 2, 'expected result count' );
	}
	
	{
		my $query	= RDF::Query->new( <<"END", { lang => 'sparql11' } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT *
			WHERE {
				GRAPH ?g {
					?p foaf:knows/foaf:name ?name .
				}
			}
END
		my $iter	= $query->execute( $model );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my @got;
		my %expect	= (
			'g1'	=> qr/Alice|Bob/,
			'g2'	=> qr/Eve/,
		);
		while (my $row = $iter->next) {
			my $g	= $row->{g}->uri_value;
			like( $g, qr/^g[12]$/, 'expected graph binding' );
			my $pat	= $expect{ $g };
			like( $row->{name}, $pat, 'expected property path value for graph ' . $g );
		}
		is( $iter->count, 3, 'expected result count' );
	}
	
}
