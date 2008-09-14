#!/usr/bin/perl

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

plan tests => 1 + (62 * scalar(@models)) + 3;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";

	{
		print "# bridge object accessors\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END", undef, 'http://jena.hpl.hp.com/2003/07/query/RDQL', undef );
			SELECT ?person
			WHERE (?person foaf:name "Gregory Todd Williams")
			USING foaf FOR <http://xmlns.com/foaf/0.1/>
END
		my $stream	= $query->execute( $model );
		is( $model, $query->bridge->model, 'model accessor' );
	}

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
		ok( $query->bridge->isa_node( $p ), 'isa_node' );
		ok( $query->bridge->isa_resource( $h ), 'isa_resource(resource)' );
		is( $query->bridge->uri_value( $h ), 'http://kasei.us/', 'http://kasei.us/' );
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
		is( $query->bridge->literal_value( $name ), 'Cliffs of Moher, Ireland', 'Cliffs of Moher, Ireland' );
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
		ok( $query->bridge->isa_resource( $person ), 'Resource' );
		is( $query->bridge->uri_value( $person ), 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
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
		ok( $query->bridge->isa_literal( $name ), 'Literal' );
		is( $query->bridge->literal_value( $name ), 'Gregory Todd Williams', 'Person name' );
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
		ok( $query->bridge->isa_resource( $results[0]{person} ), 'Person Resource' );
		ok( $query->bridge->isa_literal( $results[0]{name} ), 'Name Resource' );
		is( $query->bridge->uri_value( $results[0]{person} ), 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
		is( $query->bridge->literal_value( $results[0]{name} ), 'Gregory Todd Williams', 'Person name' );
		is( $query->bridge->literal_value($results[0]{name}), 'Gregory Todd Williams', 'Person name #2' );
		like( $query->bridge->as_string($results[0]{name}), qr'Gregory Todd Williams', 'Person name #3' );
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
		ok( $query->bridge->isa_resource( $results[0]{person} ), 'Person Resource' );
		is( $query->bridge->uri_value( $results[0]{person} ), 'http://kasei.us/about/foaf.xrdf#greg', 'Person uri' );
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
		ok( $query->bridge->isa_node($person), 'one triple, two variables (get call)' );
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
		ok( !$query->bridge->isa_resource( 0 ), 'isa_resource(0)' );
		ok( !$query->bridge->isa_resource( $name ), 'isa_resource(literal)' );
		ok( $query->bridge->isa_resource( $homepage ), 'isa_resource(resource)' );
	
		ok( !$query->bridge->isa_literal( 0 ), 'isa_literal(0)' );
		ok( !$query->bridge->isa_literal( $homepage ), 'isa_literal(resource)' );
		ok( $query->bridge->isa_literal( $name ), 'isa_literal(literal)' );
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
		ok( $query->bridge->isa_literal( $aim ), 'isa_literal' );
		like( $query->bridge->as_string($aim), qr'samofool', 'got string' );
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
		my $count;
		while (my $row = $stream->next) {
			my ($p)	= @{ $row }{qw(p)};
			ok( $p, $query->bridge->as_string( $p ) );
		} continue { ++$count };
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
		is( $query->bridge->uri_value( $result->{'a'} ), 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'rdf:type' );
		is( $query->bridge->uri_value( $result->{'b'} ), 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Property', 'rdfs:Property' );
		
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
		my $count	= 0;
		while (my $row = $stream->next) {
			my $thing	= $row->{thing};
			ok( $query->bridge->isa_blank( $thing ), 'isa blank' );
			
			my $id		= $query->bridge->blank_identifier( $thing );
			ok( length($id), 'blank identifier' );
			$count++;
		}
		is( $count, 3, '3 result' );
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
		my $bridge	= $query->bridge;
		my $lang	= $bridge->literal_value_language( $name );
		is ($lang, 'en', 'language');
	}

	{
		print "# \n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?name
			WHERE	{ ?person :name ?name }
END
		my $bridge		= $query->get_bridge( $model );
		my ($id, $name)	= ('lauren', 'Lauren Bradford');
		my $person	= $bridge->new_resource( "http://kasei.us/about/foaf.xrdf#${id}" );
		my $stream	= $query->execute( $model, bind => { person => $person } );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $p	= $row->{person};
			is( $p->uri_value, "http://kasei.us/about/foaf.xrdf#${id}", 'expected pre-bound person URI' );
			my $node	= $row->{name};
			my $value	= $query->bridge->literal_value( $node );
			is( $value, $name, 'expected name on pre-bound node' );
			$count++;
		}
		is( $count, 1, '1 result' );
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
		ok( $query->bridge->isa_node( $value ), 'binding_value_by_name' );
		
		my @names	= $stream->binding_names;
		is_deeply( ['person'], \@names, 'binding_names' );
		my @values	= $stream->binding_values;
		ok( $query->bridge->isa_node( $values[0] ), 'binding_value_by_name' );
	}

	{
		print "# SPARQL query; Stream accessors-2\n" if ($verbose);
		my $query	= new RDF::Query ( 'ASK	{ ?s ?p ?o }', undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		is( $bridge->as_string( undef ), undef );
	}
	
	{
		print "# SPARQL query; BASE declaration\n" if ($verbose);
		my $query	= new RDF::Query ( <<"END" );
			BASE <http://xmlns.com/>
			SELECT	?person
			WHERE	{ ?person <foaf/0.1/name> "Gregory Todd Williams" }
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $row		= $stream->next;
		isa_ok( $row, 'HASH' );
		ok( exists( $row->{ person } ) );
		is( $bridge->uri_value( $row->{ person } ), 'http://kasei.us/about/foaf.xrdf#greg' );
	}
}

SKIP: {
	eval "use RDF::Core; use RDF::Core::Storage::Memory; use RDF::Core::Model;";
	skip "RDF::Core not installed", 3 if $@;
	
	my $storage	= new RDF::Core::Storage::Memory;
	my $model	= new RDF::Core::Model (Storage => $storage);
	
	my $query1	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT ?page
		WHERE
			(?person foaf:name "Gregory Todd Williams")
			(?person foaf:homepage ?page)
		USING
			foaf FOR <http://xmlns.com/foaf/0.1/>
END

	my $query2	= new RDF::Query ( <<"END", undef, undef, 'rdql' );
		SELECT ?page
		WHERE
			(?person foaf:name "Gregory Todd Williams")
			(?person foaf:homepage ?page)
		USING
			foaf FOR <http://xmlns.com/foaf/0.1/>
END
	
	is( refaddr($query1->{parser}{parser}), refaddr($query2->{parser}{parser}), 'cached rdql parser' );
	throws_ok { $query1->{parser}->autoload_me_please(1,2,3) } 'RDF::Query::Error::MethodError', 'bad object autoload';
	throws_ok { RDF::Query::Parser::RDQL->autoload_me_please(1,2,3) } 'RDF::Query::Error::MethodInvocationError', 'bad class autoload';
}
