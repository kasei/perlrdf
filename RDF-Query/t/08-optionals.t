#!/usr/bin/perl
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
						?person foaf:name "Lauren Bradford" .
						OPTIONAL { ?person foaf:nick ?nick }
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->current;
		isa_ok( $row, "HASH" );
		my ($p,$n)	= @{ $row }{qw(person nick)};
		ok( $query->bridge->isa_node( $p ), 'isa_node' );
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
		while ($stream and not $stream->finished) {
			my $row		= $stream->current;
			isa_ok( $row, "HASH" );
			my ($p,$n)	= @{ $row }{qw(person nick)};
			ok( $query->bridge->isa_node( $p ), 'isa_node' );
			ok( $query->bridge->isa_literal( $n ), 'isa_literal(nick)' );
			like( ($n and $query->bridge->as_string( $n )), qr/kasei|The Samo Fool/, ($n and $query->bridge->as_string( $n )) );
			last;
		} continue { $stream->next }
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
			ok( $query->bridge->isa_node( $p ), 'isa_node' );
			ok( $query->bridge->isa_literal( $n ), 'isa_literal(nick)' );
			ok( $query->bridge->isa_resource( $h ), 'isa_resource(homepage)' );
			is( $query->bridge->uri_value( $h ), 'http://kasei.us/' );
			like( ($n and $query->bridge->as_string( $n )), qr/kasei|The Samo Fool/, ($n and $query->bridge->as_string( $n )) );
			last;
		}
	}
	
	{
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
		my $row		= $stream->current;
		isa_ok( $row, "HASH" );
		my ($p,$h)	= @{ $row }{qw(person h)};
		ok( $query->bridge->isa_node( $p ), 'isa_node(person)' );
		ok( $query->bridge->isa_node( $h ), 'isa_node(homepage)' );
	}
	
	{
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
		my $row		= $stream->current;
		isa_ok( $row, "HASH" );
		my ($p,$h,$t)	= @{ $row }{qw(person h title)};
		ok( $query->bridge->isa_node( $p ), 'isa_node' );
		is( $h, undef, 'no homepage' );
		is( $t, undef, 'no homepage title' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			SELECT	?person ?nick
			WHERE	{
						?person foaf:name "Lauren Bradford" .
						OPTIONAL { ?person foaf:nick ?nick } .
						FILTER BOUND(?nick) .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $row		= $stream->current;
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
		while ($stream and not $stream->finished) {
			my $row		= $stream->current;
			my $school	= $row->{school};
			my $str		= $query->bridge->as_string( $school );
			like( $str, qr<(smmusd|wheatonma)>, "exected school: $str" );
		} continue { $stream->next; $count++ }
		is( $count, 2, 'expected result count' );
	}
	
}
