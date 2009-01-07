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
   <eg:bar rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">23</eg:bar>
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
	is( $count, 4, 'expected count of triples matching predicate <bar>' );
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
	is( $count, 4, 'expected count on b1b,213 (requires sorting on 3-free get_statements call)' );
}

{
	my $iter	= $store->get_statements( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Variable->new('value'), undef, orderby => [ 's' => 'ASC' ] );
	isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
	my $count	= 0;
	my %seen;
	my $current;
	while (my $t = $iter->next) {
		if (defined($current)) {
			my $new	= $t->subject;
			if ($current->as_string ne $new->as_string) {
				if ($seen{ $new->as_string }++) {
					fail('distinct sorted subject value');
				} else {
					pass('distinct sorted subject value');
				}
			}
			$current	= $new;
		} else {
			$seen{ $t->subject->as_string }++;
		}
		$current	= $t->subject;
		$count++;
	}
	is( $count, 4, 'expected count on sorted get_statements call' );
}

{
	my @sorted;
	{
		my $iter	= $store->get_statements( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Variable->new('o'), undef, orderby => [ 'o' => 'ASC' ] );
		isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
		my $count	= 0;
		my %seen;
		my $current;
		while (my $t = $iter->next) {
			if (defined($current)) {
				my $new	= $t->object;
				if ($current->as_string ne $new->as_string) {
					if ($seen{ $new->as_string }++) {
						fail('distinct sorted object value');
					} else {
						pass('distinct sorted object value');
					}
					push(@sorted, $new->as_string);
				}
				$current	= $new;
			} else {
				my $s	= $t->object->as_string;
				$seen{ $s }++;
				push(@sorted, $s);
			}
			$current	= $t->object;
			$count++;
		}
		is( $count, 4, 'expected count on sorted get_statements call' );
	}
	
	{
		my $iter	= $store->get_statements( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Resource->new('http://example.org/bar'), RDF::Trine::Node::Variable->new('o'), undef, orderby => [ 'o' => 'DESC' ] );
		my $current;
		while (my $t = $iter->next) {
			if (defined($current)) {
				my $new	= $t->object;
				if ($current->as_string ne $new->as_string) {
					is( $new->as_string, pop(@sorted), 'expected reverse sorted object value' );
				}
				$current	= $new;
			} else {
				my $s	= $t->object->as_string;
				is( $s, pop(@sorted), 'expected reverse sorted object value' );
			}
			$current	= $t->object;
		}
	}
}

{
	my @sorted;
	{
		my $iter	= $store->get_statements( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Variable->new('p'), RDF::Trine::Node::Variable->new('o'), undef, orderby => [ 'o' => 'ASC' ] );
		isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
		my $count	= 0;
		my %seen;
		my $current;
		while (my $t = $iter->next) {
			if (defined($current)) {
				my $new	= $t->object;
				if ($current->as_string ne $new->as_string) {
					if ($seen{ $new->as_string }++) {
						fail('distinct sorted object value');
					} else {
						pass('distinct sorted object value');
					}
					push(@sorted, $new->as_string);
				}
				$current	= $new;
			} else {
				my $s	= $t->object->as_string;
				$seen{ $s }++;
				push(@sorted, $s);
			}
			$current	= $t->object;
			$count++;
		}
		is( $count, 5, 'expected count on sorted get_statements call' );
	}
	
	{
		my $iter	= $store->get_statements( RDF::Trine::Node::Variable->new('s'), RDF::Trine::Node::Variable->new('p'), RDF::Trine::Node::Variable->new('o'), undef, orderby => [ 'o' => 'DESC' ] );
		my $current;
		while (my $t = $iter->next) {
			if (defined($current)) {
				my $new	= $t->object;
				if ($current->as_string ne $new->as_string) {
					is( $new->as_string, pop(@sorted), 'expected reverse sorted object value' );
				}
				$current	= $new;
			} else {
				my $s	= $t->object->as_string;
				is( $s, pop(@sorted), 'expected reverse sorted object value' );
			}
			$current	= $t->object;
		}
	}
}

################

sub _add_rdf {
	my $store	= shift;
	my $data	= shift;
	my $base	= shift || 'http://example.org/';
	my $parser	= RDF::Trine::Parser::RDFXML->new();
	$parser->parse_into_model( $base, $data, $store );
}

