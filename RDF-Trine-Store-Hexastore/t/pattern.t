use Test::More qw(no_plan); # tests => 183;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);
use File::Temp qw(tempfile);

use RDF::Trine;
use RDF::Trine::Pattern;
use RDF::Trine::Store::Hexastore;


my $store	= RDF::Trine::Store::Hexastore->new();
_add_rdf( $store, <<"END" );
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
 <rdf:Description rdf:about="http://example.org/foo">
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">23</eg:bar>
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">24</eg:bar>
   <eg:baz>quux</eg:baz>
 </rdf:Description>
 <rdf:Description rdf:about="http://example.org/zzz">
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">999</eg:bar>
 </rdf:Description>
</rdf:RDF>
END

{
	my $p1		= RDF::Trine::Statement->new( RDF::Trine::Node::Variable->new('p'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Variable->new('value') );
	my $pattern	= RDF::Trine::Pattern->new( $p1 );
	my $iter	= $store->get_pattern( $pattern );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	my $count	= 0;
	while (my $row = $iter->next) {
		isa_ok( $row, 'HASH' );
		my $value	= $row->{ value };
		isa_ok( $value, 'RDF::Trine::Node::Literal' );
		like( $value->literal_value, qr/^(23|24|999)$/, 'expected literal numeric value' );
		$count++;
	}
	is( $count, 3 );
}

{
	# <zzz> ?p 999 .
	# ?s ?p ?value .
	my $p1		= RDF::Trine::Statement->new( RDF::Trine::Node::Resource->new('http://example.org/zzz'), RDF::Trine::Node::Variable->new('p'), RDF::Trine::Node::Literal->new('999', undef, 'http://www.w3.org/2001/XMLSchema#integer') );
	my $p2		= RDF::Trine::Statement->new( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Variable->new('p'), RDF::Trine::Node::Variable->new('value') );
	my $pattern	= RDF::Trine::Pattern->new( $p1, $p2 );
	my $iter	= $store->get_pattern( $pattern );
	isa_ok( $iter, 'RDF::Trine::Iterator::Bindings' );
	my $count	= 0;
	while (my $row = $iter->next) {
		isa_ok( $row, 'HASH' );
		like( $row->{'s'}->uri_value, qr<http://example.org/(zzz|foo)$>, 'expected subject variable' );
		is( $row->{'p'}->uri_value, 'http://example.org/bar', 'expected predicate variable' );
		like( $row->{'value'}->literal_value, qr<^(23|24|999)$>, 'expected object variable' );
		$count++;
	}
	is( $count, 3 );
}

################

sub _add_rdf {
	my $store	= shift;
	my $data	= shift;
	my $base	= shift || 'http://example.org/';
	my $parser	= RDF::Trine::Parser::RDFXML->new();
	$parser->parse_into_model( $base, $data, $store );
}

