#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Test::More qw(no_plan);
use Test::Exception;
use File::Spec;

use RDF::Base::Node;
use_ok( 'RDF::Base::Parser' );

{
	my $parser	= RDF::Base::Parser->new();
	isa_ok( $parser, 'RDF::Base::Parser' );
	isa_ok( $parser->_impl, 'RDF::Base::Parser::RDFXML' );
}

{
	my $parser	= RDF::Base::Parser->new( name => 'turtle' );
	isa_ok( $parser, 'RDF::Base::Parser' );
	isa_ok( $parser->_impl, 'RDF::Base::Parser::Turtle' );
}

{
	my $parser	= RDF::Base::Parser->new( mimetype => 'application/rdf+xml' );
	isa_ok( $parser, 'RDF::Base::Parser' );
	isa_ok( $parser->_impl, 'RDF::Base::Parser::RDFXML' );
}

{
	dies_ok{
		my $parser	= RDF::Base::Parser->new( name => 'unknown' );
	} 'unknown parser';
}

{
	my $parser	= RDF::Base::Parser->new();
	my $file	= File::Spec->rel2abs( 't/test.rdf' );
	my $uri		= RDF::Base::Node::Resource->new( uri => "file://${file}" );
	my $stream	= $parser->parse_as_stream( $uri, $uri );
	
	my $count	= 0;
	my $cmp		= RDF::Base::Statement->parse( qq({[http://example.com/], [http://www.w3.org/2000/01/rdf-schema#label], "Example"} [file://${file}]) );
	while (my $st = $stream->next) {
		ok( $st->equal( $cmp ), 'expected stream statement' );
		$count++;
	}
	is( $count, 1, 'expected rdf+xml parse count' );
}

{
	my $parser	= RDF::Base::Parser->new( name => 'simple' );
	my $file	= File::Spec->rel2abs( 't/test.simple' );
	my $uri		= RDF::Base::Node::Resource->new( uri => "file://${file}" );
	my $stream	= $parser->parse_as_stream( $uri, $uri );
	
	my @cmps;
	push(@cmps, RDF::Base::Statement->parse( '{[http://example.com/], [http://www.w3.org/2000/01/rdf-schema#label], "Example"}' ));
	push(@cmps, RDF::Base::Statement->parse( '{[http://example.com/], [http://purl.org/dc/elements/1.1/title], "Example Site"}' ));
	
	my $count	= 0;
	while (my $st = $stream->next) {
		ok( $st->equal( shift(@cmps) ), 'expected stream statement' );
		$count++;
	}
	is( $count, 2, 'expected simple parse count' );
}

__END__
