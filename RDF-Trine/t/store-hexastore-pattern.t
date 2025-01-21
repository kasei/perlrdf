use Test::More qw(no_plan); # tests => 183;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);
use File::Temp qw(tempfile);

use RDF::Trine qw(iri literal variable statement);
use RDF::Trine::Pattern;
use RDF::Trine::Store::Hexastore;


my $store	= RDF::Trine::Store::Hexastore->new();
_add_rdf( $store, <<'END');
@prefix eg: <http://example.org/> .

eg:foo
    eg:bar 23, 24 ;
    eg:baz "quux" .

eg:zzz
    eg:bar 23, 999 .
END

{
	my $p1		= statement( variable('p'), iri('http://example.org/bar'), variable('value') );
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
	my $p1		= statement(
					iri('http://example.org/zzz'),
					variable('p'),
					literal('999', undef, 'http://www.w3.org/2001/XMLSchema#integer')
				);
	my $p2		= statement(
					variable('s'),
					variable('p'),
					variable('value')
				);
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
	my $iter	= $store->get_statements( variable('s'), iri('http://example.org/bar'), variable('value'), undef, orderby => [ 's' => 'ASC' ] );
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
		my $iter	= $store->get_statements( variable('s'), iri('http://example.org/bar'), variable('o'), undef, orderby => [ 'o' => 'ASC' ] );
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
		my $iter	= $store->get_statements( variable('s'), iri('http://example.org/bar'), variable('o'), undef, orderby => [ 'o' => 'DESC' ] );
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
		my $iter	= $store->get_statements( variable('s'), variable('p'), variable('o'), undef, orderby => [ 'o' => 'ASC' ] );
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
		my $iter	= $store->get_statements( variable('s'), variable('p'), variable('o'), undef, orderby => [ 'o' => 'DESC' ] );
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
	my $parser	= RDF::Trine::Parser::Turtle->new();
	my $model	= RDF::Trine::Model->new($store);
	$parser->parse_into_model( $base, $data, $model );
}

