#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Test::More qw(no_plan);
use Test::Exception;
use File::Spec;

use RDF::Query::Node;
use_ok( 'RDF::Base::Parser' );

{
	my $parser	= RDF::Base::Parser->new();
	isa_ok( $parser, 'RDF::Base::Parser' );
	isa_ok( $parser->_impl, 'RDF::Base::Parser::RDFXML' );
}

{
	my $parser	= RDF::Base::Parser->new( mimetype => 'application/rdf+xml' );
	isa_ok( $parser, 'RDF::Base::Parser' );
	isa_ok( $parser->_impl, 'RDF::Base::Parser::RDFXML' );
}

{
	my $parser	= RDF::Base::Parser->new();
	my $file	= File::Spec->rel2abs( 't/test2.rdf' );
	my $uri		= RDF::Query::Node::Resource->new( uri => "file://${file}" );
	my $stream	= $parser->parse_as_stream( $uri, $uri );
	
	my $count	= 0;
	my $cmp		= RDF::Base::Statement->parse( qq({[http://example.com/], [http://www.w3.org/2000/01/rdf-schema#label], "Example"} [file://${file}]) );
	while (my $st = $stream->next) {
		ok( $st->equal( $cmp ), 'expected stream statement' );
		$count++;
	}
	is( $count, 1, 'expected rdf+xml parse count' );
}

__END__
