#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf);
my @models	= test_models( @files );
my $tests	= 1 + (scalar(@models) * 31);
plan tests => $tests;

use_ok( 'RDF::Query' );
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?nick
			WHERE	{
						?person foaf:name "Lauren B" .
						OPTIONAL { ?person foaf:nick ?nick }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->next;
		isa_ok( $row, "HASH" );
		my ($p,$n)	= @{ $row }{qw(person nick)};
		ok( $p->isa('RDF::Trine::Node'), 'isa_node' );
		is( $n, undef, 'missing nick' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?nick
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						OPTIONAL { ?person foaf:nick ?nick }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $row = $stream->next) {
			isa_ok( $row, "HASH" );
			my ($p,$n)	= @{ $row }{qw(person nick)};
			ok( $p->isa('RDF::Trine::Node'), 'isa_node' );
			ok( $n->isa('RDF::Trine::Node::Literal'), 'isa_literal(nick)' );
			like( ($n and $n->as_string), qr/kasei|The Samo Fool/, ($n and $n->as_string) );
			last;
		}
	}
	
	{
		print "# optional with trailing triples\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?nick ?page
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						OPTIONAL { ?person foaf:nick ?nick } .
						?person foaf:homepage ?page
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		while (my $row = $stream->next) {
			isa_ok( $row, "HASH" );
			my ($p,$n,$h)	= @{ $row }{qw(person nick page)};
			ok( $p->isa('RDF::Trine::Node'), 'isa_node' );
			ok( $n->isa('RDF::Trine::Node::Literal'), 'isa_literal(nick)' );
			ok( $h->isa('RDF::Trine::Node::Resource'), 'isa_resource(homepage)' );
			is( $h->uri_value, 'http://kasei.us/' );
			like( ($n and $n->as_string), qr/kasei|The Samo Fool/, ($n and $n->as_string) );
			last;
		}
	}
	
	{
		print "# 1-triple optional\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	?person ?h
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						OPTIONAL {
							?person foaf:homepage ?h .
						}
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->next;
		isa_ok( $row, "HASH" );
		my ($p,$h)	= @{ $row }{qw(person h)};
		ok( $p->isa('RDF::Trine::Node'), 'isa_node(person)' );
		ok( $h->isa('RDF::Trine::Node'), 'isa_node(homepage)' );
	}
	
	{
		print "# 2-triple optional\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	?person ?h ?title
			WHERE	{
						?person foaf:name "Gregory Todd Williams" .
						OPTIONAL {
							?person foaf:homepage ?h .
							?h dc:title ?title
						}
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->next;
		isa_ok( $row, "HASH" );
		my ($p,$h,$t)	= @{ $row }{qw(person h title)};
		ok( $p->isa('RDF::Trine::Node'), 'isa_node' );
		is( $h, undef, 'no homepage' );
		is( $t, undef, 'no homepage title' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?nick
			WHERE	{
						?person foaf:name "Lauren B" .
						OPTIONAL { ?person foaf:nick ?nick } .
						FILTER BOUND(?nick) .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->next;
		ok( not($row), 'no results: successful BOUND() filter' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?school
			WHERE	{
						?person a foaf:Person ; foaf:nick "kasei" .
						OPTIONAL {
							?person foaf:schoolHomepage ?school .
						} .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			my $school	= $row->{school};
			my $str		= $school->as_string;
			like( $str, qr<(smmusd|wheatonma)>, "exected school: $str" );
			$count++;
		}
		is( $count, 2, 'expected result count' );
	}
	
}
