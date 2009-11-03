#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use File::Spec;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my $tests	= 11;
my @models	= test_models( qw(data/foaf.xrdf data/about.xrdf) );
plan tests => 1 + ($tests * scalar(@models));

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	SKIP: {
		{
			print "# DATATYPE() comparison\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				PREFIX dc: <http://purl.org/dc/elements/1.1/>
				SELECT ?image ?date
				WHERE {
					?image a foaf:Image ;
						dc:date ?date .
					FILTER ( datatype(?date) = xsd:dateTime )
					
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				my ($image, $dt)	= @{ $row }{qw(image date)};
				my $url		= $query->bridge->uri_value( $image );
				my $date	= $query->bridge->literal_value( $dt );
				like( $date, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[-+]\d\d:\d\d$/, "valid date: $date" );
				$count++;
			}
			is( $count, 2, "2 photo found with typed date" );
		}

		{
			print "# LANG() comparison\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				PREFIX dc: <http://purl.org/dc/elements/1.1/>
				SELECT ?person ?name
				WHERE {
					?person a foaf:Person ;
						foaf:name ?name .
					FILTER ( LANG(?name) = "en" )
					
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				my ($p, $n)	= @{ $row }{qw(person name)};
				my $person	= $query->bridge->as_string( $p );
				my $name	= $query->bridge->literal_value( $n );
				is( $name, 'Gary P', "english name: $name" );
				$count++;
			}
			is( $count, 1, "1 person found with an english-typed name" );
		}

		{
			print "# LANGMATCHES()\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				PREFIX dc: <http://purl.org/dc/elements/1.1/>
				SELECT ?person ?name
				WHERE {
					?person a foaf:Person ;
						foaf:name ?name .
					FILTER ( LANGMATCHES(LANG(?name), "en") )
					
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				my ($p, $n)	= @{ $row }{qw(person name)};
				my $person	= $query->bridge->as_string( $p );
				my $name	= $query->bridge->literal_value( $n );
				is( $name, 'Gary P', "english name: $name" );
				$count++;
			}
			is( $count, 1, "1 person found with an english-typed name" );
		}

		{
			print "# dateTime type promotion and equality\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				ASK {
					FILTER ( xsd:dateTime("1994-11-05T08:15:30-05:00") = "1994-11-05T13:15:30Z"^^xsd:dateTime ) .
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			my $ok		= $stream->get_boolean();
			ok( $ok, 'op:dateTime-equal' );
		}
		
		{
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				ASK {
					FILTER ( xsd:dateTime("1994-11-05T08:15:30-08:00") = "1994-11-05T13:15:30Z"^^xsd:dateTime ) .
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			my $ok		= $stream->get_boolean();
			ok( not($ok), 'not op:dateTime-equal' );
		}
		
		{
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				ASK {
					FILTER ( "1995-11-05"^^xsd:dateTime > "1994-11-05T13:15:30Z"^^xsd:dateTime ) .
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			my $ok		= $stream->get_boolean();
			ok( $ok, 'dateTime-greater-than' );
		}
		
		{
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
				ASK {
					FILTER ( "1995-11-05"^^xsd:dateTime <= "1994-11-05T13:15:30Z"^^xsd:dateTime ) .
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			my $ok		= $stream->get_boolean();
			ok( not($ok), 'not dateTime-less-than-or-equal' );
		}
		
		{
			# coalesce
			my $query	= new RDF::Query ( <<"END", { lang => 'sparql2' } );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT * WHERE {
					?p a foaf:Person .
					OPTIONAL {
						?p foaf:aimChatID ?aim .
					}
					FILTER(COALESCE(?aim,"unknown") = "unknown")
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next()) {
				$count++;
			}
			is($count, 3, 'coalesce simple');
		}
		
		{
			# coalesce
			my $query	= new RDF::Query ( <<"END", { lang => 'sparql2' } );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT (COALESCE(?aim) AS ?name) WHERE {
					?p a foaf:Person .
					OPTIONAL {
						?p foaf:aimChatID ?aim .
					}
				}
END
			warn RDF::Query->error unless ($query);
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next()) {
				warn $row;
				$count++;
			}
			is($count, 4, 'coalesce type-error');
		}
		
	}
}
