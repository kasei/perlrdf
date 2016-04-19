#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;

use lib qw(. t);
BEGIN { require "models.pl"; }

use Test::More;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.trine.store.dbi = TRACE, Screen
# 	log4perl.category.rdf.query     = TRACE, Screen
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

my @models	= test_models();

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
			is( $src->uri_value, $alice, 'graph uri' );
			is( $name->literal_value, 'Alice', 'name literal' );
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
			my ($plan, $ctx)	= $query->prepare( $model );
			my $stream	= $query->execute_plan( $plan, $ctx );
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
				
				my $uri	= $mbox->uri_value;
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
			my ($plan, $ctx)	= $query->prepare( $model );
			my $iter	= $query->execute_plan( $plan, $ctx );
			while (my $row = $iter->next) {
				my $src		= $row->{src};
				my $mbox	= $row->{mbox};
				ok( $src, 'got source' );
				ok( $mbox, 'got mbox' );
				is( $src->uri_value, $alice, 'graph uri' );
				is( $mbox->uri_value, 'mailto:alice@work.example', 'mbox uri' );
			}
			is( $iter->seen_count, 1, 'expected result count' );
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
				my $uri	= $graph->uri_value;
				
				ok( exists $expected{ $uri }, "Known GRAPH: $uri" );
				
				my $expect	= $expected{ $uri };
				
				ok( $name, 'got name' );
				
				my $l_name	= $name->literal_value;
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
			
			my $stream	= $query->execute( $model );
			while (my $row = $stream->next) {
				isa_ok( $row, 'HASH' );
				
				my ($graph, $name, $topic)	= @{ $row }{qw(g name topic)};
				my $uri	= $graph->uri_value;
				
				ok( exists $expected{ $uri }, "Known GRAPH: $uri" );
				
				my $expect	= $expected{ $uri };
				
				ok( $name, 'got name' );
				ok( $topic, 'got topic' );
				
				my $l_name	= $name->literal_value;
				my $l_topic	= $topic->literal_value;
				is( $l_name, $expect, "got name: $l_name" );
				is( $l_topic, $expect, "got topic: $l_topic" );
			}
			
			is( $stream->seen_count, 2, 'got results' );
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
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while ($stream and not $stream->finished) {
			my $row		= $stream->current;
			my ($p,$g,$i)	= @{ $row }{qw(p g img)};
			ok( $g->isa('RDF::Trine::Node::Resource'), 'graph-3: context is resource' );
			ok( $p->isa('RDF::Trine::Node::Resource'), 'graph-3: person is resource' );
			is( $p->uri_value, 'http://kasei.us/about/foaf.xrdf#greg', 'graph-3: correct person uri' );
			like( $i->uri_value, qr/[.]jpg/, 'graph-3: made image' );
			$count++;
		} continue { $stream->next }
		is( $count, 4, 'graph-3: expected count' );
	}
	
	{
		print "# find all graph names\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' ) or die RDF::Query->error;
			SELECT ?g
			FROM NAMED <${alice}>
			FROM NAMED <${bob}>
			WHERE {
				GRAPH ?g {} .
			}
END
		
		my $count	= 0;
		my $stream	= $query->execute( $model );
		while (my $row = $stream->next) {
			isa_ok( $row, 'HASH' );
			my $g	= $row->{g};
			isa_ok( $g, 'RDF::Query::Node::Resource' );
			like( $g->uri_value, qr/(alice|bob).rdf$/, 'expected graph name' );
			$count++;
		}
		
		is( $count, 2, 'two expected graph names' );
	}
}

done_testing();
