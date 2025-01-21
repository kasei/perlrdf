use Test::More tests => 7;
use Test::Exception;

use strict;
use warnings;
use File::Spec;

use RDF::Trine qw(iri);
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser;

throws_ok { RDF::Trine::Parser->new('guess') } 'RDF::Trine::Error::UnimplementedError', "Guess parser isn't implemented yet";
throws_ok { RDF::Trine::Parser->new('foobar') } 'RDF::Trine::Error::ParserError', "RDF::Trine::Parser constructor throws on unrecognized parser name";


SKIP: {
	unless ($ENV{RDFTRINE_NETWORK_TESTS}) {
		skip( "No network. Set RDFTRINE_NETWORK_TESTS to run these tests.", 5 );
	}
	
	{
		my $url		= 'http://kasei.us/about/foaf.xrdf';
		my $model	= RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
		
		try {
			RDF::Trine::Parser->parse_url_into_model( $url, $model );
			pass('parse_url_into_model succeeded');
		} catch RDF::Trine::Error::ParserError with {
			fail('parse_url_into_model failed');
		};
		
		ok( $model->size, 'parsed statements' );
		my $count	= $model->count_statements( iri('http://kasei.us/about/foaf.xrdf#greg'), $rdf->type, $foaf->Person );
		is( $count, 1, 'expected statement' );
	}
	
	{
		my $url		= 'http://kasei.us/bad_file.ttl';
		my $model	= RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
		throws_ok {
			RDF::Trine::Parser->parse_url_into_model( $url, $model );
		} 'RDF::Trine::Error::ParserError', 'parse_url_into_model throws on bad URL';
	}
	
	{
		my $url		= 'tag:gwilliams@cpan.org,2012-10-18:foobar';
		my $model	= RDF::Trine::Model->new(RDF::Trine::Store->temporary_store);
		throws_ok {
			RDF::Trine::Parser->parse_url_into_model( $url, $model );
		} 'RDF::Trine::Error::ParserError', 'parse_url_into_model throws on bad URL hostname';
	}
}
