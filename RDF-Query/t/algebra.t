#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 35;
use Test::Exception;
use Scalar::Util qw(reftype blessed);

use RDF::Query;

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		[
			a foaf:PersonalProfileDocument ;
			foaf:maker [
				a foaf:Person ;
				foaf:name ?name
			]
		] .
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ $pattern->referenced_variables ], ['name'], 'ppd: referenced_variables' );
	is_deeply( [ $pattern->definite_variables ], ['name'], 'ppd: definite_variables' );
	is_deeply( [ $pattern->referenced_blanks ], ['a1', 'a2'], 'ppd: referenced_blanks' );
	
}

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		?p a foaf:Person ;
			foaf:name ?name .
		OPTIONAL {
			?p foaf:homepage ?page .
		}
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ sort $pattern->referenced_variables ], [qw(name p page)], 'foaf-simple: referenced_variables' );
	is_deeply( [ sort $pattern->definite_variables ], [qw(name p)], 'foaf-simple: definite_variables' );
	is_deeply( [ sort $pattern->referenced_blanks ], [], 'foaf-simple: referenced_blanks' );
	
}

{
	my $sparql	= <<"END";
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT ?name
	WHERE {
		{
			?p a foaf:Person ;
				foaf:name ?name .
			OPTIONAL {
				?p foaf:homepage ?page .
			}
		} UNION {
			?d a foaf:Document ;
				dc:title ?name .
		}
	}
END
	my $query	= RDF::Query->new( $sparql );
	my $pattern	= $query->pattern;
	isa_ok( $pattern, 'RDF::Query::Algebra' );
	is_deeply( [ sort $pattern->referenced_variables ], [qw(d name p page)], 'union: referenced_variables' );
	is_deeply( [ sort $pattern->definite_variables ], [qw(name)], 'union: definite_variables' );
	is_deeply( [ sort $pattern->referenced_blanks ], [], 'union: referenced_blanks' );
}

{
	# SORTING
	my $bz		= RDF::Query::Node::Blank->new( 'z' );
	my $bb		= RDF::Query::Node::Blank->new( 'b' );
	my $ba		= RDF::Query::Node::Blank->new( 'a' );
	
	my $lb		= RDF::Query::Node::Literal->new( 'b' );
	my $la		= RDF::Query::Node::Literal->new( 'a' );
	my $lal		= RDF::Query::Node::Literal->new( 'a', 'en' );
	my $l2d		= RDF::Query::Node::Literal->new( '2.0', undef, 'http://www.w3.org/2001/XMLSchema#float' );
	my $l1d		= RDF::Query::Node::Literal->new( '1', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
	my $l01d	= RDF::Query::Node::Literal->new( '01', undef, 'http://www.w3.org/2001/XMLSchema#integer' );
	
	my $rea	= RDF::Query::Node::Resource->new( 'http://example.org/a' );
	my $reb	= RDF::Query::Node::Resource->new( 'http://example.org/b' );
	my $lea	= RDF::Query::Node::Literal->new( 'http://example.org/a' );
	
	{
		cmp_ok( $ba, '<', $bb, 'blank less-than' );
		cmp_ok( $bb, '>', $ba, 'blank greater-than' );
		cmp_ok( $ba, '!=', $bb, 'blank not-eq' );
		cmp_ok( $ba, '==', $ba, 'blank eq' );
	}
	
	{
		cmp_ok( $la, '<', $lb, 'literal less-than' );
		cmp_ok( $lb, '>', $la, 'literal greater-than' );
		cmp_ok( $la, '!=', $lb, 'literal not-eq' );
		cmp_ok( $la, '==', $la, 'literal eq' );
# 		cmp_ok( $la, '<', $lal, 'same-valued plain- and language-literals are unsortable' );
		throws_ok {
			$la <=> $l1d
		} 'RDF::Query::Error::TypeError', 'different-valued plain- and datatype-literals are sortable';
		cmp_ok( $l1d, '==', $l01d, 'numeric-datatype-literals are sortable (equal, but not sameTerm)' );
		cmp_ok( $l2d, '>', $l1d, 'numeric-datatype-literals are sortable (greater-than, but different numeric type)' );
	}
	
	{
		cmp_ok( $rea, '<', $reb, 'resource less-than' );
		cmp_ok( $reb, '>', $rea, 'resource greater-than' );
		cmp_ok( $rea, '!=', $reb, 'resource not-eq' );
		cmp_ok( $rea, '==', $rea, 'resource eq' );
	}
	
	{
		cmp_ok( $bz, '<', $la, 'blank less-than resource (different value)' );
		cmp_ok( $rea, '<', $lea, 'resource less-than literal (same value)' );
		cmp_ok( $rea, '<', $la, 'resource less-than literal (different value)' );
	}
	
}


{
	# Accessing Subpatterns
	{
		my $sparql	= <<"END";
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		SELECT ?name
		WHERE { [ a foaf:PersonalProfileDocument ; foaf:maker [ a foaf:Person ; foaf:name ?name ] ] }
END
		my $query	= RDF::Query->new( $sparql );
		my $pattern	= $query->pattern;
		my @triples	= $pattern->subpatterns_of_type('RDF::Query::Algebra::Triple');
		is( scalar(@triples), 4, 'count of triple subpatterns' );
	}
	
	{
		my $sparql	= <<"END";
	PREFIX  foaf:   <http://xmlns.com/foaf/0.1/>
	PREFIX    ex:   <http://example.org/things#>
	SELECT ?name ?plan ?dept ?img 
	WHERE 
	{ 
		?person foaf:name ?name  
		{ ?person ex:healthplan ?plan } UNION { ?person ex:department ?dept } 
		OPTIONAL { 
			?person a foaf:Person
			GRAPH ?g { 
				[] foaf:name ?name;
				   foaf:depiction ?img 
			} 
		} 
	}
END
		my $query	= RDF::Query->new( $sparql );
		my $pattern	= $query->pattern;
		my @bgps	= $pattern->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern');
		is( scalar(@bgps), 5, 'count of bgp subpatterns' );
		is_deeply(
			$bgps[3],
			bless( [
				bless([
					bless( ['person'], 'RDF::Query::Node::Variable' ),
					bless( ['URI','http://www.w3.org/1999/02/22-rdf-syntax-ns#type'], 'RDF::Query::Node::Resource' ),
					bless( ['URI','http://xmlns.com/foaf/0.1/Person'], 'RDF::Query::Node::Resource' )
				], 'RDF::Query::Algebra::Triple' )
			], 'RDF::Query::Algebra::BasicGraphPattern' ),
			'RDF::Query::Algebra::BasicGraphPattern'
		);
		
		my ($optional)	= $pattern->subpatterns_of_type('RDF::Query::Algebra::Optional');
		my @obgps	= $optional->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern');
		is( scalar(@obgps), 5, 'count of bgp subpatterns under optional' );
		my ($graph)	= $pattern->subpatterns_of_type('RDF::Query::Algebra::NamedGraph');
		is_deeply(
			$graph,
			bless( [ 'GRAPH',
				bless( ['g'], 'RDF::Query::Node::Variable' ),
				bless( [
					bless( [
						bless( [
							bless( ['BLANK','a1'], 'RDF::Query::Node::Blank' ),
							bless( ['URI','http://xmlns.com/foaf/0.1/name'], 'RDF::Query::Node::Resource' ),
							bless( ['name'], 'RDF::Query::Node::Variable' ),
						], 'RDF::Query::Algebra::Triple' ),
						bless( [
							bless( ['BLANK','a1'], 'RDF::Query::Node::Blank' ),
							bless( ['URI','http://xmlns.com/foaf/0.1/depiction'], 'RDF::Query::Node::Resource' ),
							bless( ['img'], 'RDF::Query::Node::Variable' ),
						], 'RDF::Query::Algebra::Triple' )
					], 'RDF::Query::Algebra::BasicGraphPattern' )
				], 'RDF::Query::Algebra::GroupGraphPattern' )
			], 'RDF::Query::Algebra::NamedGraph' ),
			'deep comparison on GRAPH subpattern'
		);
	}
}
