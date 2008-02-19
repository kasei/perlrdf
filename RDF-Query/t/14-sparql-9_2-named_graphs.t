#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

my @models	= test_models();

my $tests	= 58;
plan tests => 1 + ($tests * scalar(@models));
# plan qw(no_plan);	# the number of tests is currently broken because named graphs
# 					# are adding triples to the underyling model. when that's fixed,
# 					# this should be changed back to a test number.

my $alice	= URI::file->new_abs( 'data/named_graphs/alice.rdf' );
my $bob		= URI::file->new_abs( 'data/named_graphs/bob.rdf' );
my $meta	= URI::file->new_abs( 'data/named_graphs/meta.rdf' );

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n";
	SKIP: {
		{
			print "# variable named graph\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?src ?name
				FROM NAMED <${alice}>
				WHERE {
					GRAPH ?src { ?x foaf:name ?name }
				}
END
			my ($src, $name)	= $query->get( $model );
			ok( $src, 'got source' );
			
			ok( $name, 'got name' );		
			is( $query->bridge->uri_value( $src ), $alice, 'graph uri' );
			is( $query->bridge->literal_value( $name ), 'Alice', 'name literal' );
		}
		
		{
			print "# uri named graph (fail: graph)\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?name
				FROM NAMED <${alice}>
				WHERE {
					GRAPH <foo:bar> { ?x foaf:name ?name }
				}
END
			my $stream	= $query->execute( $model );
			my $row		= $stream->next;
			is( $row, undef, 'no results' );
		}
		
		{
			print "# uri named graph (fail: pattern)\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?src ?name
				FROM NAMED <${alice}>
				WHERE {
					GRAPH ?src { ?x <foo:bar> ?name }
				}
END
			my $stream	= $query->execute( $model );
			my $row		= $stream->next;
			is( $row, undef, 'no results' );
		}
		
		{
			print "# uri named graph with multiple graphs\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?mbox
				FROM NAMED <${alice}>
				FROM NAMED <${bob}>
				WHERE {
					GRAPH <$bob> { ?x foaf:mbox ?mbox } .
				}
END
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				isa_ok( $row, 'HASH' );
				
				my $mbox	= $row->{mbox};
				ok( $mbox, 'got mbox' );
				
				my $uri	= $query->bridge->uri_value( $mbox );
				is( $uri, 'mailto:bob@oldcorp.example.org', "mbox uri: $uri" );
				$count++;
			}
			
			is( $count, 1, 'one result' );
		}
		
		{
			print "# variable named graph with multiple graphs; select from one\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?src ?mbox
				FROM NAMED <${alice}>
				FROM NAMED <${bob}>
				WHERE {
					GRAPH ?src { ?x foaf:name "Alice"; foaf:mbox ?mbox } .
				}
END
			my ($src, $mbox)	= $query->get( $model );
			ok( $src, 'got source' );
			ok( $mbox, 'got mbox' );
			is( $query->bridge->uri_value( $src ), $alice, 'graph uri' );
			is( $query->bridge->uri_value( $mbox ), 'mailto:alice@work.example', 'mbox uri' );
		}
		
		{
			print "# variable named graph with multiple graphs; select from both\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?g ?name
				FROM NAMED <${alice}>
				FROM NAMED <${bob}>
				FROM <${meta}>
				WHERE {
					GRAPH ?g { ?x foaf:name ?name } .
				}
END
			
			my %expected	= (
								$alice	=> "Alice",
								$bob	=> "Bob",
							);
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			
			
			while (my $row = $stream->current) {
				$stream->next;
				isa_ok( $row, 'HASH' );
				
				my ($graph, $name)	= @{ $row }{qw(g name)};
				my $uri	= $query->bridge->uri_value( $graph );
				
				ok( exists $expected{ $uri }, "Known GRAPH: $uri" );
				
				my $expect	= $expected{ $uri };
				
				ok( $name, 'got name' );
				
				my $l_name	= $query->bridge->literal_value( $name );
				is( $l_name, $expect, "got name: $l_name" );
				$count++;
			}
			
			is( $count, 2, 'got results' );
		}
		
		{
			print "# variable named graph with multiple graphs; non-named graph triples\n";
			my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
				PREFIX foaf: <http://xmlns.com/foaf/0.1/>
				SELECT ?g ?name ?topic
				FROM NAMED <${alice}>
				FROM NAMED <${bob}>
				FROM <${meta}>
				WHERE {
					GRAPH ?g { ?x foaf:name ?name } .
					?g foaf:topic ?topic .
				}
END
			
			my %expected	= (
								$alice	=> "Alice",
								$bob	=> "Bob",
							);
			
			my $count	= 0;
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				isa_ok( $row, 'HASH' );
				
				my ($graph, $name, $topic)	= @{ $row }{qw(g name topic)};
				my $uri	= $query->bridge->uri_value( $graph );
				
				ok( exists $expected{ $uri }, "Known GRAPH: $uri" );
				
				my $expect	= $expected{ $uri };
				
				ok( $name, 'got name' );
				ok( $topic, 'got topic' );
				
				my $l_name	= $query->bridge->literal_value( $name );
				my $l_topic	= $query->bridge->literal_value( $topic );
				is( $l_name, $expect, "got name: $l_name" );
				is( $l_topic, $expect, "got topic: $l_topic" );
				$count++;
			}
			
			is( $count, 2, 'got results' );
		}
	}

	{
		print "# graph-1\n";
		my $foaf	= URI::file->new_abs( "data/foaf.xrdf" );
		my $about	= URI::file->new_abs( "data/about.xrdf" );
		
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			SELECT DISTINCT ?s ?o
			FROM <$foaf>
			FROM NAMED <$about>
			WHERE	{
						?s dcterms:spatial ?o
					}
END
		my $stream	= $query->execute();
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $data = $stream->next) {
			$count++;
		}
		is( $count, 0, 'graph-1: BGP does not match NAMED data' );
	}

	{
		print "# graph-2\n";
		my $foaf	= URI::file->new_abs( "data/foaf.xrdf" );
		my $about	= URI::file->new_abs( "data/about.xrdf" );
		
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			SELECT DISTINCT ?g ?s
			FROM <$foaf>
			FROM NAMED <$about>
			WHERE	{
						GRAPH ?g { ?s foaf:firstName "Gary" }
					}
END
		my $stream	= $query->execute();
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $data = $stream->next) {
			$count++;
		}
		is( $count, 0, 'graph-2: GRAPH does not match non-NAMED data' );
	}
	
	{
		print "# graph-3\n";
		my $foaf	= URI::file->new_abs( "data/foaf.xrdf" );
		my $about	= URI::file->new_abs( "data/about.xrdf" );
		
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT DISTINCT ?p ?g ?img
			FROM <$foaf>
			FROM NAMED <$about>
			WHERE	{
						?p a foaf:Person .
						GRAPH ?g { ?img foaf:maker ?p } .
					}
END
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while ($stream and not $stream->finished) {
			my $row		= $stream->current;
			my ($p,$g,$i)	= @{ $row }{qw(p g img)};
			ok( $bridge->is_resource( $g ), 'graph-3: context is resource' );
			ok( $bridge->is_resource( $p ), 'graph-3: person is resource' );
			is( $bridge->uri_value( $p ), 'http://kasei.us/about/foaf.xrdf#greg', 'graph-3: correct person uri' );
			like( $bridge->uri_value( $i ), qr/[.]jpg/, 'graph-3: made image' );
			$count++;
		} continue { $stream->next }
		is( $count, 4, 'graph-3: expected count' );
	}
}
