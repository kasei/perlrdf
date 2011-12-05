use Test::More qw(no_plan); # tests => 183;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);

use RDF::Trine;
use RDF::Trine::Store::Hexastore;

my $store	= RDF::Trine::Store::Hexastore->new();
isa_ok( $store, 'RDF::Trine::Store::Hexastore' );

_add_rdf( $store, <<"END" );
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
 <rdf:Description rdf:about="http://example.org/foo">
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">23</eg:bar>
 </rdf:Description>
</rdf:RDF>
END

{
	my @nodes	= (
		RDF::Trine::Node::Resource->new('http://example.org/foo'),
		RDF::Trine::Node::Resource->new('http://example.org/bar'),
		RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer'),
	);
	my $st		= RDF::Trine::Statement->new( @nodes );
	my $iter	= $store->get_statements( @nodes );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $next	= $iter->next;
	is_deeply( $next, $st, 'got expected statement by 3-bound query' );
}

{
	my @nodes	= (
		RDF::Trine::Node::Resource->new('http://example.org/foo'),
		RDF::Trine::Node::Resource->new('http://example.org/bar'),
		RDF::Trine::Node::Literal->new('00', undef, 'http://www.w3.org/2001/XMLSchema#integer'),
	);
	my $st		= RDF::Trine::Statement->new( @nodes );
	my $iter	= $store->get_statements( @nodes );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $next	= $iter->next;
	is_deeply( $next, undef, 'got expected empty statement iterator by 3-bound query' );
}

{
	my @nodes	= (
		RDF::Trine::Node::Resource->new('http://example.org/foo'),
		RDF::Trine::Node::Resource->new('http://example.org/bar'),
		undef,
	);
	my $st		= RDF::Trine::Statement->new( @nodes[0,1], RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer') );
	my $iter	= $store->get_statements( @nodes );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
		is_deeply( $next, $st, 'got expected statement by 2-bound query' );
		$count++;
	}
	is( $count, 1, 'iterator had expected single element' );
}

_add_rdf( $store, <<"END" );
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
 <rdf:Description rdf:about="http://example.org/zzz">
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">999</eg:bar>
 </rdf:Description>
 <rdf:Description rdf:about="http://example.org/foo">
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">24</eg:bar>
   <eg:baz>quux</eg:baz>
 </rdf:Description>
</rdf:RDF>
END

{
	my @nodes	= (
		RDF::Trine::Node::Resource->new('http://example.org/foo'),
		RDF::Trine::Node::Resource->new('http://example.org/bar'),
		undef,
	);
	my @expect	= (
		RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer'),
		RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer'),
	);
	my $iter	= $store->get_statements( @nodes );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
		my $e		= shift(@expect);
		unless (blessed($e)) {
			fail('no more nodes are expected, but one was found');
		}
		my $st		= RDF::Trine::Statement->new( @nodes[0,1], $e );
		is_deeply( $next, $st, 'got expected statement by 2-bound query' );
		$count++;
	}
	is( $count, 2, 'iterator had 2 expected element (after adding new data)' );
}

{
	my @nodes	= (
		RDF::Trine::Node::Resource->new('http://example.org/foo'),
		undef,
		undef,
	);
	my @expect	= (
		[ RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/baz'), RDF::Trine::Node::Literal->new('quux') ],
	);
	my $iter	= $store->get_statements( @nodes );
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
		my $e		= shift(@expect);
		unless (ref($e)) {
			fail('no more nodes are expected, but one was found');
		}
		my $st		= RDF::Trine::Statement->new( $nodes[0], @$e );
		is_deeply( $next, $st, 'got expected statement by 1-bound query' );
		$count++;
	}
	is( $count, 3, 'iterator had 3 expected element' );
}

{
	my @expect	= (
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/baz'), RDF::Trine::Node::Literal->new('quux') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/zzz'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('999', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
	);
	my $iter	= $store->get_statements();
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
		my $e		= shift(@expect);
		unless (ref($e)) {
			fail('no more nodes are expected, but one was found');
		}
		my $st		= RDF::Trine::Statement->new( @$e );
		is_deeply( $next, $st, 'got expected statement by all wildcard query' );
		$count++;
	}
	is( $count, 4, 'iterator had 4 expected element' );
}


is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo') ), 3, 'count_statements(bff) returned 3' );
is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/zzz') ), 1, 'count_statements(bff) returned 1' );
is( $store->count_statements( undef, RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 3, 'count_statements(fbf) returned 3' );
is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), undef ), 2, 'count_statements(bbf) returned 2' );
is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer') ), 1, 'count_statements(bbb) returned 1' );
is( $store->count_statements( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('12345', undef, 'http://www.w3.org/2001/XMLSchema#integer') ), 0, 'count_statements(bbb) returned 0' );
is( $store->count_statements, 4, 'count_statements(fff) returned expected 4' );

$store->remove_statement( RDF::Trine::Statement->new( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('23', undef, 'http://www.w3.org/2001/XMLSchema#integer') ) );

{
	my @expect	= (
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/baz'), RDF::Trine::Node::Literal->new('quux') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/zzz'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('999', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
	);
	my $iter	= $store->get_statements();
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
		my $e		= shift(@expect);
		unless (ref($e)) {
			fail('no more nodes are expected, but one was found');
		}
		my $st		= RDF::Trine::Statement->new( @$e );
		is_deeply( $next, $st, 'got expected statement by all wildcard query (after removing a statement)' );
		$count++;
	}
	is( $count, 3, 'iterator had 3 expected element' );
}

$store->remove_statement( RDF::Trine::Statement->new( RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/baz'), RDF::Trine::Node::Literal->new('quux') ) );

{
	my @expect	= (
		[ RDF::Trine::Node::Resource->new('http://example.org/foo'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('24', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
		[ RDF::Trine::Node::Resource->new('http://example.org/zzz'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Literal->new('999', undef, 'http://www.w3.org/2001/XMLSchema#integer') ],
	);
	my $iter	= $store->get_statements();
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my $count	= 0;
	while (my $next = $iter->next) {
# 		use Data::Dumper;
# 		warn Dumper($next);
		my $e		= shift(@expect);
		unless (ref($e)) {
			fail('no more nodes are expected, but one was found');
		}
		my $st		= RDF::Trine::Statement->new( @$e );
		is_deeply( $next, $st, 'got expected statement by all wildcard query (after removing a second statement)' );
		$count++;
	}
	is( $count, 2, 'iterator had 2 expected element' );
}


{
	is($store->size, 2, 'pre-nuke size test shows 2 statements in store');
	$store->nuke;
	is($store->size, 0, 'post-nuke size test shows 0 statements in store');
	my $count	= $store->count_statements( undef, undef, undef, undef );
	is($count, 0, 'post-nuke count test shows 0 statements in store');
	my $iter	= $store->get_statements( undef, undef, undef, undef );
	my $next	= $iter->next;
	ok(! defined($next), 'Iterator gave no result' );
}



################

sub _add_rdf {
	my $store	= shift;
	my $data	= shift;
	my $base	= shift || 'http://example.org/';
	my $parser	= RDF::Trine::Parser::RDFXML->new();
	$parser->parse_into_model( $base, $data, $store );
}

