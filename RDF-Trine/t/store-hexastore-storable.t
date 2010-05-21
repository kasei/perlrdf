use Test::More qw(no_plan); # tests => 183;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);
use File::Temp qw(tempfile);

use RDF::Trine;
use RDF::Trine::Store::Hexastore;


(undef, my $filename) = tempfile();

{
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
	$store->store( $filename );
}

{
	my $store	= RDF::Trine::Store::Hexastore->load( $filename );
	isa_ok( $store, 'RDF::Trine::Store::Hexastore' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo') ), 3, 'count_statements(bff) returned 3' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/zzz') ), 1, 'count_statements(bff) returned 1' );
	is( $store->count_statements( undef, RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 3, 'count_statements(fbf) returned 3' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 2, 'count_statements(bbf) returned 2' );
	is( $store->count_statements, 4, 'count_statements(fff) returned expected 4' );
}

{
	my $store	= RDF::Trine::Store->new_with_string('Hexastore;Storable;file='.$filename );
	isa_ok( $store, 'RDF::Trine::Store::Hexastore' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo') ), 3, 'count_statements(bff) returned 3' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/zzz') ), 1, 'count_statements(bff) returned 1' );
	is( $store->count_statements( undef, RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 3, 'count_statements(fbf) returned 3' );
	is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 2, 'count_statements(bbf) returned 2' );
	is( $store->count_statements, 4, 'count_statements(fff) returned expected 4' );
}

################

sub _add_rdf {
	my $store	= shift;
	my $data	= shift;
	my $base	= shift || 'http://example.org/';
	my $parser	= RDF::Trine::Parser::RDFXML->new();
	$parser->parse_into_model( $base, $data, $store );
}

