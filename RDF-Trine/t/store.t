use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace;

use Log::Log4perl;

Log::Log4perl->easy_init if $ENV{TEST_VERBOSE};

my @stores	= test_stores();
plan tests => 5 + scalar(@stores) * 167;

my $ex		= RDF::Trine::Namespace->new('http://example.com/');
my @names	= ('a' .. 'z');
my @triples;
my @quads;

{
	isa_ok( store( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'Memory' ), 'RDF::Trine::Store::Memory' );
	isa_ok( RDF::Trine::Store->new_with_string( 'SPARQL;http://example/' ), 'RDF::Trine::Store::SPARQL' );
}

my $nil	= RDF::Trine::Node::Nil->new();
foreach my $i (@names[0..2]) {
	my $w	= $ex->$i();
	foreach my $j (@names[0..2]) {
		my $x	= $ex->$j();
		foreach my $k (@names[0..2]) {
			my $y	= $ex->$k();
			my $triple	= RDF::Trine::Statement->new($w,$x,$y);
			push(@triples, $triple);
			foreach my $l (@names[0..2]) {
				my $z	= $ex->$l();
				my $quad	= RDF::Trine::Statement::Quad->new($w,$x,$y,$z);
				push(@quads, $quad);
			}
		}
	}
}

foreach my $store (@stores) {
	print "### Testing store " . ref($store) . "\n";
	isa_ok( $store, 'RDF::Trine::Store' );
	
	throws_ok {
		my $st	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d);
		$store->add_statement( $st, $ex->e );
	} 'RDF::Trine::Error::MethodInvocationError', 'add_statement throws when called with quad and context';
	
	throws_ok {
		my $st	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d);
		$store->remove_statement( $st, $ex->e );
	} 'RDF::Trine::Error::MethodInvocationError', 'remove_statement throws when called with quad and context';
	
	add_statement_tests_simple( $store );
	count_statements_tests_simple( $store );
	add_quads( $store );
	count_statements_tests_quads( $store );
	add_triples( $store );
	count_statements_tests_triples( $store );
	contexts_tests( $store );
	get_statements_tests_triples( $store );
	get_statements_tests_quads( $store );
# 	orderby_tests( $store );
	remove_statement_tests( $store );
}

{
	my $store	= RDF::Trine::Store::Memory->new();
	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d) );
	$store->add_statement( RDF::Trine::Statement::Quad->new($ex->r, $ex->t, $ex->u, $ex->v) );
	is( $store->_statement_id($ex->a, $ex->t, $ex->c, $ex->d), -1, '_statement_id' );
	is( $store->_statement_id($ex->w, $ex->x, $ex->z, $ex->z), -1, '_statement_id' );
}

sub add_quads {
	my $store	= shift;
	foreach my $q (@quads) {
		$store->add_statement( $q );
	}
}

sub add_triples {
	my $store	= shift;
	foreach my $t (@triples) {
		$store->add_statement( $t );
	}
}

sub contexts_tests {
	print "# contexts tests\n";
	my $store	= shift;
	my $iter	= $store->get_contexts();
	isa_ok( $iter, 'RDF::Trine::Iterator' );
	my %seen;
	while (my $c = $iter->next) {
		isa_ok( $c, 'RDF::Trine::Node' );
		$seen{ $c->as_string }++;
	}
	my $expect	= {
					'<http://example.com/a>'	=> 1,
					'<http://example.com/b>'	=> 1,
					'<http://example.com/c>'	=> 1,
				};
	is_deeply( \%seen, $expect, 'expected contexts' );
}

sub add_statement_tests_simple {
	print "# simple add_statement tests\n";
	my $store	= shift;
	
	my $triple	= RDF::Trine::Statement->new($ex->a, $ex->b, $ex->c);
	my $quad	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d);
	$store->add_statement( $triple, $ex->d );
	is( $store->size, 1, 'store has 1 statement after (triple+context) add' );
	$store->add_statement( $quad );
	is( $store->size, 1, 'store has 1 statement after duplicate (quad) add' );
	$store->remove_statement( $triple, $ex->d );
	is( $store->size, 0, 'store has 0 statements after (triple+context) remove' );
	
	my $quad2	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, iri('graph'));
	$store->add_statement( $quad2 );
	is( $store->size, 1, 'store has 1 statement after (quad) add' );
	
	my $count	= $store->count_statements( undef, undef, undef, iri('graph') );
	is( $count, 1, 'expected count of specific-context statements' );
	
	$store->remove_statement( $quad2 );
	is( $store->size, 0, 'expected zero size after remove statement' );
}

sub count_statements_tests_simple {
	print "# simple count_statements tests\n";
	my $store	= shift;
	
	{
		is( $store->size, 0, 'expected zero size before add statement' );
		my $st	= RDF::Trine::Statement::Quad->new( $ex->a, $ex->b, $ex->c, $ex->d );
		$store->add_statement( $st );

		is( $store->size, 1, 'size' );
		is( $store->count_statements(), 1, 'count_statements()' );
		is( $store->count_statements(undef, undef, undef), 1, 'count_statements(fff) with undefs' );
		is( $store->count_statements(map {variable($_)} qw(s p o)), 1, 'count_statements(fff) with variables' );
		is( $store->count_statements(undef, undef, undef, undef), 1, 'count_statements(ffff) with undefs' );
		is( $store->count_statements(map {variable($_)} qw(s p o g)), 1, 'count_statements(ffff) with variables' );
		
		# 1-bound
		is( $store->count_statements($ex->a, undef, undef, undef), 1, 'count_statements(bfff)' );
		is( $store->count_statements(undef, $ex->b, undef, undef), 1, 'count_statements(fbff)' );
		is( $store->count_statements(undef, undef, $ex->c, undef), 1, 'count_statements(ffbf)' );
		is( $store->count_statements(undef, undef, undef, $ex->d), 1, 'count_statements(fffb)' );
		
		# 2-bound
#		local($::debug)	= 1;
		is( $store->count_statements($ex->a, $ex->b, undef, undef), 1, 'count_statements(bbff)' );
		is( $store->count_statements(undef, $ex->b, $ex->c, undef), 1, 'count_statements(fbbf)' );
		is( $store->count_statements(undef, undef, $ex->c, $ex->d), 1, 'count_statements(ffbb)' );
		is( $store->count_statements($ex->a, undef, undef, $ex->d), 1, 'count_statements(bffb)' );
		
		$store->remove_statement( $st );
		is( $store->size, 0, 'size' );
	}
	
	is( $store->count_statements( $ex->z, undef, undef, undef ), 0, 'count_statements(bfff) empty result set' );
	is( $store->count_statements( $ex->z, undef, undef, $ex->x ), 0, 'count_statements(bffb) empty result set' );
	
}

sub count_statements_tests_quads {
	print "# quad count_statements tests\n";
	my $store	= shift;
	{
		is( $store->count_statements, 27, 'count_statements()' );
		is( $store->count_statements(undef, undef, undef), 27, 'count_statements( fff )' );
		is( $store->count_statements(undef, undef, undef, undef), 81, 'count_statements( ffff )' );
		
		is( $store->count_statements( $ex->a, undef, undef ), 9, 'count_statements( bff )' );
		is( $store->count_statements( $ex->a, undef, undef, undef ), 27, 'count_statements( bfff )' );
		is( $store->count_statements( $ex->a, undef, undef, $ex->a ), 9, 'count_statements( bffb )' );
	}
}

sub count_statements_tests_triples {
	print "# triple count_statements tests\n";
	my $store	= shift;
	
	{
		is( $store->count_statements, 27, 'count_statements() after triples added' );
		is( $store->count_statements(undef, undef, undef), 27, 'count_statements( fff ) after triples added' );
		is( $store->count_statements(undef, undef, undef, undef), 108, 'count_statements( ffff ) after triples added' );
		
		is( $store->count_statements( $ex->a, undef, undef ), 9, 'count_statements( bff )' );
		is( $store->count_statements( $ex->a, undef, undef, undef ), 27+9, 'count_statements( bfff )' );
		is( $store->count_statements( $ex->a, undef, undef, $nil ), 9, 'count_statements( bffb )' );
	}
}

sub get_statements_tests_triples {
	print "# triple get_statements tests\n";
	my $store	= shift;
	
	{
		my $iter	= $store->get_statements( undef, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 27, 'get_statements( fff ) expected result count'  );
		is( $iter->next, undef, 'triple iterator end-of-stream' );
	}
	
	{
		my $iter	= $store->get_statements( $ex->a, variable('p'), variable('o') );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			ok( $st->subject->equal( $ex->a ), 'expected triple get_statements bound subject' );
			$count++;
		}
		is( $count, 9, 'get_statements( bff ) expected result count'  );
	}
	
	{
		my $iter	= $store->get_statements( $ex->d, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 0, 'get_statements( bff ) expected empty results'  );
	}
}

sub get_statements_tests_quads {
	print "# quad get_statements tests\n";
	my $store	= shift;
	
	{
		my $iter	= $store->get_statements( undef, undef, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 108, 'get_statements( ffff ) expected result count'  );
		is( $iter->next, undef, 'quad iterator end-of-stream' );
	}
	
	{
		my $iter	= $store->get_statements( $ex->a, , variable('p'), variable('o'), variable('g') );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			ok( $st->subject->equal( $ex->a ), 'expected triple get_statements bound subject' );
			$count++;
		}
		is( $count, 27+9, 'get_statements( bfff ) expected result count'  );
	}
	
	{
		my $iter	= $store->get_statements( $ex->d, undef, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 0, 'get_statements( bfff ) expected empty results'  );
	}
	
	{
		my $iter	= $store->get_statements( undef, undef, undef, $nil );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 27, 'get_statements( fffb ) expected result count 1'  );
	}
	
	{
		my $iter	= $store->get_statements( undef, undef, undef, $ex->a );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			ok( $st->context->equal( $ex->a ), 'expected triple get_statements bound context' );
			$count++;
		}
		is( $count, 27, 'get_statements( fffb ) expected result count 2'  );
	}
	
	{
		my $iter	= $store->get_statements( $ex->a, $ex->b, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			ok( $st->subject->equal( $ex->a ), 'expected triple get_statements bound subject' );
			ok( $st->predicate->equal( $ex->b ), 'expected triple get_statements bound predicate' );
			$count++;
		}
		is( $count, 9+3, 'get_statements( bbff ) expected result count'  );
	}
	
	{
		my $iter	= $store->get_statements( $ex->a, $ex->z, undef, undef );
		isa_ok( $iter, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $st = $iter->next()) {
			$count++;
		}
		is( $count, 0, 'get_statements( bbff ) expected empty result'  );
	}
	
}

sub orderby_tests {
	print "# orderby tests\n";
	my $store	= shift;
	
	{
		my $iter	= $store->get_statements( undef, undef, undef, undef, orderby => 'predicate' );
		isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
		my $last;
		while (my $st = $iter->next) {
			my $pred	= $st->predicate;
			
			if (defined($last)) {
				my $cmp	= $last->compare( $pred );
				cmp_ok( $cmp, '<=', 0 );
			}
			$last	= $pred;
		}
	}
}

sub remove_statement_tests {
	print "# remove_statement tests\n";
	my $store	= shift;
	is( $store->count_statements( undef, undef, undef, undef ), 108, 'store size before quad removal' );
	foreach my $i (@names[0..2]) {
		my $w	= $ex->$i();
		foreach my $j (@names[0..2]) {
			my $x	= $ex->$j();
			foreach my $k (@names[0..2]) {
				my $y	= $ex->$k();
				foreach my $l (@names[0..2]) {
					my $z	= $ex->$l();
					my $quad	= RDF::Trine::Statement::Quad->new($w,$x,$y,$z);
					$store->remove_statement( $quad );
				}
			}
		}
	}
	is( $store->count_statements( undef, undef, undef, undef ), 27, 'quad count after quad removal' );
	is( $store->count_statements( undef, undef, undef ), 27, 'triple count after quad removal' );
	
	$store->remove_statements( $ex->a, undef, undef, undef );
	is( $store->count_statements( undef, undef, undef ), 18, 'triple count after remove_statements( bfff )' );
	
	foreach my $i (@names[0..2]) {
		my $w	= $ex->$i();
		foreach my $j (@names[0..2]) {
			my $x	= $ex->$j();
			foreach my $k (@names[0..2]) {
				my $y	= $ex->$k();
				my $triple	= RDF::Trine::Statement->new($w,$x,$y);
				$store->remove_statement( $triple );
			}
		}
	}
	is( $store->count_statements( undef, undef, undef, undef ), 0, 'quad count after triple removal' );
}

sub test_stores {
	my @stores;
	push(@stores, RDF::Trine::Store::DBI->temporary_store());
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	if ($RDF::Trine::Store::HAVE_REDLAND) {
		push(@stores, RDF::Trine::Store::Redland->temporary_store());
	}
	return @stores;
}
