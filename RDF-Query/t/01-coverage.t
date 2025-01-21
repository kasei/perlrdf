#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';
use Test::Exception;
use Scalar::Util qw(refaddr);

use lib qw(. t);
BEGIN { require "models.pl"; }

my $verbose	= 1;
my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );

use Test::More;

use_ok( 'RDF::Query' );
use RDF::Query::Node qw(iri);
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";

	{
		print "# using RDQL language URI\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", { lang => 'rdql' } );
			SELECT
				?person
			WHERE
				(?person foaf:name "Gregory Todd Williams")
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
	}

	{
		print "# using SPARQL language URI\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person
			WHERE	{ ?person foaf:name "Gregory Todd Williams" }
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
	}

	{
		print "# SPARQL query\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?homepage
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						?person foaf:homepage ?homepage .
						FILTER REGEX(str(?homepage), "kasei")
					}
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'results' );
		my $row		= $results[0];
		my ($p,$h)	= @{ $row }{qw(person homepage)};
		ok( $p->isa('RDF::Trine::Node'), 'isa_node' );
		ok( $h->isa('RDF::Trine::Node::Resource'), 'isa_resource(resource)' );
		is( $h->uri_value, 'http://kasei.us/', 'http://kasei.us/' );
	}

	{
		print "# geo:Point with geo:lat\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?name
			WHERE	{
						[ a geo:Point; geo:lat "52.972770"; foaf:name ?name ]
					}
END
		my ($name)	= $query->get( $model );
		ok( $name, 'got name' );
		is( $name->literal_value, 'Cliffs of Moher, Ireland', 'Cliffs of Moher, Ireland' );
	}

	{
		print "# RDQL query\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:name "Gregory Todd Williams")
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my ($person)	= $query->get( $model );
		ok( $person->isa('RDF::Trine::Node::Resource'), 'Resource' );
		is( $person->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
	}

	{
		print "# Triple with QName subject\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?name
			WHERE
				(kasei:greg foaf:name ?name)
			USING
				kasei FOR <http://kasei.us/about/foaf.xrdf#>
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my ($name)	= $query->get( $model );
		ok( $name->isa('RDF::Trine::Node::Literal'), 'Literal' );
		is( $name->literal_value, 'Gregory Todd Williams', 'Person name' );
	}

	{
		print "# Early triple with multiple unbound variables\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person ?name
			WHERE
				(?person foaf:name ?name)
				(?person foaf:homepage <http://kasei.us/>)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my @results	= $query->execute( $model );
		ok( $results[0]{person}->isa('RDF::Trine::Node::Resource'), 'Person Resource' );
		ok( $results[0]{name}->isa('RDF::Trine::Node::Literal'), 'Name Resource' );
		is( $results[0]{person}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
		is( $results[0]{name}->literal_value, 'Gregory Todd Williams', 'Person name' );
		like( $results[0]{name}->as_string, qr'Gregory Todd Williams', 'Person name #2' );
	}

	{
		print "# Triple with no variable, present in data\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:name "Gregory Todd Williams")
				(<http://kasei.us/about/foaf.xrdf#greg> foaf:homepage <http://kasei.us/>)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my @results	= $query->execute( $model );
		ok( $results[0]{person}->isa('RDF::Trine::Node::Resource'), 'Person Resource' );
		is( $results[0]{person}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
	}

	{
		print "# Triple with no variable, not present in data\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:name "Gregory Todd Williams")
				(<http://localhost/greg> foaf:homepage <http://kasei.us/>)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my @results	= $query->execute( $model );
		is( scalar(@results), 0, 'No data returned for bogus triple' );
	}

	{
		print "# Query with one triple, two variables\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(?person foaf:name ?name)
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'one triple, two variables (query call)' );
	
		my ($person)	= $query->get( $model );
		ok( $person->isa('RDF::Trine::Node'), 'one triple, two variables (get call)' );
	}

	{
		print "# Broken query triple (variable with missing '?')\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?person
			WHERE
				(person foaf:name "Gregory Todd Williams")
			USING
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
		is( $query, undef, 'Error (undef row) on no triples (query call)' );
	}

	{
		print "# Backend tests\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
			SELECT
				?name ?homepage
			WHERE
				(kasei:greg foaf:name ?name)
				(kasei:greg foaf:homepage ?homepage)
			USING
				kasei FOR <http://kasei.us/about/foaf.xrdf#>
				foaf FOR <http://xmlns.com/foaf/0.1/>
END
	
		my ($name,$homepage)	= $query->get( $model );
		ok( !$name->isa('RDF::Trine::Node::Resource'), 'isa_resource(literal)' );
		ok( $homepage->isa('RDF::Trine::Node::Resource'), 'isa_resource(resource)' );
	
		ok( !$homepage->isa('RDF::Trine::Node::Literal'), 'isa_literal(resource)' );
		ok( $name->isa('RDF::Trine::Node::Literal'), 'isa_literal(literal)' );
	}

	{
		print "# SPARQL getting foaf:aimChatID by foaf:nick\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?aim WHERE { ?p foaf:nick "kasei"; foaf:aimChatID ?aim }
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
		my $row		= $results[0];
		my ($aim)	= @{ $row }{qw(aim)};
		ok( $aim->isa('RDF::Trine::Node::Literal'), 'isa_literal' );
		like( $aim->as_string, qr'samofool', 'got string' );
	}

	{
		print "# SPARQL getting foaf:aimChatID by foaf:nick on non-existant person\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			SELECT ?aim WHERE { ?p foaf:nick "libby"; foaf:aimChatID ?aim }
END
		my @results	= $query->execute( $model );
		is( scalar(@results), 0, '0 results' );
	}

	{
		print "# SPARQL getting blank nodes (geo:Points) and sorting by genid\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT ?p
			WHERE { ?p a geo:Point }
			ORDER BY ?p
			LIMIT 2
END
		my $stream	= $query->execute( $model );
		while (my $row = $stream->next) {
			my ($p)	= @{ $row }{qw(p)};
			ok( $p, $p->as_string );
		}
	}

	{
		print "# broken query with get call\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			break me
END
		is( $query, undef, 'broken query with get call' );
	}

	{
		print "# SPARQL query with missing (optional) WHERE\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person { ?person foaf:name "Gregory Todd Williams" }
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
	}

	{
		print "# SPARQL query with SELECT *\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
		SELECT *
		WHERE { ?a ?a ?b . }
END
		my @results	= $query->execute( $model );
		is( scalar(@results), 1, 'got one result' );
		my $result	= $results[0];
		is( $result->{'a'}->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'rdf:type' );
		is( $result->{'b'}->uri_value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Property', 'rdfs:Property' );
		
	}

	{
		print "# SPARQL query with default namespace\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	: <http://xmlns.com/foaf/0.1/>
			SELECT	?person
			WHERE	{ ?person :name "Gregory Todd Williams" }
END
		my @results	= $query->execute( $model );
		ok( scalar(@results), 'got result' );
	}

	{
		print "# SPARQL query; blank node results\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	wn: <http://xmlns.com/wordnet/1.6/>
			SELECT	?thing
			WHERE	{
				?image a foaf:Image ;
					foaf:depicts ?thing .
				?thing a wn:Flower-2 .
			}
END
		my $stream	= $query->execute( $model );
		while (my $row = $stream->next) {
			my $thing	= $row->{thing};
			ok( $thing->isa('RDF::Trine::Node::Blank'), 'isa blank' );
			
			my $id		= $thing->blank_identifier;
			ok( length($id), 'blank identifier' );
		}
		is( $stream->seen_count, 3, '3 result' );
	}

	{
		print "# SPARQL query; language-typed literal\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?name
			WHERE	{
				?p a foaf:Person ;
					foaf:mbox_sha1sum "2057969209f1dfdad832de387cf13e6ff8c93b12" ;
					foaf:name ?name .
			}
END
		my ($name)	= $query->get( $model );
		my $lang	= $name->literal_value_language;
		is ($lang, 'en', 'language');
	}

	{
		print "# \n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?name
			WHERE	{ ?person :name ?name }
END
		my ($id, $name)	= ('lauren', 'Lauren B');
		my $person	= iri( "http://kasei.us/about/foaf.xrdf#${id}" );
		my $stream	= $query->execute( $model, bind => { person => $person } );
		while (my $row = $stream->next) {
			my $p	= $row->{person};
			is( $p->uri_value, "http://kasei.us/about/foaf.xrdf#${id}", 'expected pre-bound person URI' );
			my $node	= $row->{name};
			my $value	= $node->literal_value;
			is( $value, $name, 'expected name on pre-bound node' );
		}
		is( $stream->seen_count, 1, '1 result' );
	}

	{
		print "# SPARQL query; Stream accessors-1\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://www.w3.org/TR/rdf-sparql-query/', undef );
			PREFIX	: <http://xmlns.com/foaf/0.1/>
			SELECT	?person
			WHERE	{ ?person :name "Gregory Todd Williams" }
END
		my $stream	= $query->execute( $model );
		my $value	= $stream->binding_value_by_name('person');
		is( $value, $stream->binding_value( 0 ), 'binding_value' );
		ok( $value->isa('RDF::Trine::Node'), 'binding_value_by_name' );
		
		my @names	= $stream->binding_names;
		is_deeply( ['person'], \@names, 'binding_names' );
		my @values	= $stream->binding_values;
		ok( $values[0]->isa('RDF::Trine::Node'), 'binding_value_by_name' );
	}

	{
		print "# SPARQL query; BASE declaration\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END" );
			BASE <http://xmlns.com/>
			SELECT	?person
			WHERE	{ ?person <foaf/0.1/name> "Gregory Todd Williams" }
END
		my $stream	= $query->execute( $model );
		my $row		= $stream->next;
		isa_ok( $row, 'HASH' );
		ok( exists( $row->{ person } ) );
		is( $row->{person}->uri_value, 'http://kasei.us/about/foaf.xrdf#greg' );
	}
}

done_testing();
