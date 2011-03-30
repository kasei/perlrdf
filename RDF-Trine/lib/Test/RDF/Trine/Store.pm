=head1 NAME

Test::RDF::Trine::Store - A collection of functions to test RDF::Trine::Stores

=head1 VERSION

This document describes RDF::Trine version 0.134

=head1 SYNOPSIS

For example, to test a Memory store, do something like:

  use Test::RDF::Trine::Store qw(all_store_tests number_of_tests);
  use Test::More tests => 1 + Test::RDF::Trine::Store::number_of_tests;

  use RDF::Trine qw(iri variable store literal);
  use RDF::Trine::Store;

  my $data = Test::RDF::Trine::Store::create_data;

  my $store	= RDF::Trine::Store::Memory->temporary_store();
  isa_ok( $store, 'RDF::Trine::Store::Memory' );
  Test::RDF::Trine::Store::all_store_tests($store, $data);



=head1 DESCRIPTION

This packages a few functions that you can call to test a
L<RDF::Trine::Store>, also if it is outside of the main RDF-Trine
distribution.

There are different functions that will test different parts of the
functionality, but you should run them all at some point, thus for the
most part, you would just like to run the C<all_store_tests> function.

All the below functions are exported.


=cut

package Test::RDF::Trine::Store;

use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Store::DBI;
use RDF::Trine::Namespace qw(xsd);

use Log::Log4perl;

Log::Log4perl->easy_init if $ENV{TEST_VERBOSE};

our @EXPORT = qw(number_of_tests create_data all_store_tests add_quads add_triples contexts_tests add_statement_tests_simple count_statements_tests_simple count_statements_tests_quads count_statements_tests_triples get_statements_tests_triples get_statements_tests_quads orderby_tests remove_statement_tests);



=head1 FUNCTIONS

=over 4

=item C<< number_of_tests >>

Returns the number of tests run with C<all_store_tests>.

=cut

sub number_of_tests {
  return 203; # Remember to update whenever adding tests
}


=item C<< create_data >>

Returns a hashref with generated test data nodes to be used by other
tests.

=cut


sub create_data {
  my $ex		= RDF::Trine::Namespace->new('http://example.com/');
  my @names	= ('a' .. 'z');
  my @triples;
  my @quads;
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
  return { ex => $ex, names => \@names, triples => \@triples, quads => \@quads, nil => $nil };
}

=item C<< all_store_tests ($store, $data) >>

Will run all available tests for the given store, given the data from
C<create_data>.

=cut

sub all_store_tests {
        my ($store, $data) = @_;

	my $ex	    = $data->{ex};
	my @names   = @{$data->{names}};
	my @triples = @{$data->{triples}};
	my @quads   = @{$data->{quads}};
	my $nil	    = $data->{nil};

	note "## Testing store " . ref($store);
	isa_ok( $store, 'RDF::Trine::Store' );

      TODO: {
	local $TODO = $store->isa('RDF::Trine::Store::Redland') ? 'Redland has context issues' : undef;
	  
	throws_ok {
	  my $st	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d);
	  $store->add_statement( $st, $ex->e );
	} 'RDF::Trine::Error::MethodInvocationError', 'add_statement throws when called with quad and context';
      
	
	throws_ok {
		my $st	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $ex->c, $ex->d);
		$store->remove_statement( $st, $ex->e );
	} 'RDF::Trine::Error::MethodInvocationError', 'remove_statement throws when called with quad and context';
	
	add_statement_tests_simple( $store, $ex );
	literals_tests_simple( $store, $ex );
	blank_node_tests_simple( $store, $ex );
	count_statements_tests_simple( $store, $ex );
	add_quads( $store, @quads );
	count_statements_tests_quads( $store, $ex );
	add_triples( $store, @triples );
	count_statements_tests_triples( $store, $ex, $nil );
	contexts_tests( $store );
	get_statements_tests_triples( $store, $ex );
	get_statements_tests_quads( $store, $ex, $nil  );
# 	orderby_tests( $store );
	remove_statement_tests( $store, $ex, @names );
      }
}

=item C<< add_quads($store, @quads) >>

Helper function to add an array of quads to the given store.

=cut


sub add_quads {
	my ($store, @quads) = @_;
	foreach my $q (@quads) {
		$store->add_statement( $q );
	}
}


=item C<< add_triples($store, @triples) >>

Helper function to add an array of triples to the given store.

=cut

sub add_triples {
	my ($store, @triples) = @_;
	foreach my $t (@triples) {
		$store->add_statement( $t );
	}
}

=item C<< contexts_tests( $store ) >>

Testing contexts (aka. "graphs")

=cut


sub contexts_tests {
	note "contexts tests";
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


=item C<< add_statement_tests_simple( $store, $data->{ex} )  >>

Tests to check add_statement.

=cut


sub add_statement_tests_simple {
	note "simple add_statement tests";
	my ($store, $ex) = @_;
	
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


=item C<< literals_tests_simple( $store, $data->{ex} )  >>

Tests to check literals support.

=cut

sub literals_tests_simple {
	note "simple tests with literals";
	my ($store, $ex) = @_;
	
	my $litplain    = RDF::Trine::Node::Literal->new('dahut');
	my $litlang1    = RDF::Trine::Node::Literal->new('dahu', 'fr' );
	my $litlang2    = RDF::Trine::Node::Literal->new('dahut', 'en' );
	my $litstring   = RDF::Trine::Node::Literal->new('dahut', undef, $xsd->string);
	my $litint      = RDF::Trine::Node::Literal->new(42, undef, $xsd->integer);
	my $triple	= RDF::Trine::Statement->new($ex->a, $ex->b, $litplain);
	my $quad	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $litplain, $ex->d);
	$store->add_statement( $triple, $ex->d );
	is( $store->size, 1, 'store has 1 statement after (triple+context) add' );
	$store->add_statement( $quad );
	is( $store->size, 1, 'store has 1 statement after duplicate (quad) add' );
	$store->remove_statement( $triple, $ex->d );
	is( $store->size, 0, 'store has 0 statements after (triple+context) remove' );

	$store->add_statement( $quad );
	my $quad2	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $litlang2, $ex->d);
	$store->add_statement( $quad2 );
	is( $store->size, 2, 'store has 2 statements after (quad) add' );
	
	{
	  my $count	= $store->count_statements( undef, undef, $litplain, undef );
	  is( $count, 1, 'expected 1 plain literal' );
	}

	{
	  my $count	= $store->count_statements( undef, undef, $litlang2, undef );
	  is( $count, 1, 'expected 1 language literal' );
	}

	{
	  my $count	= $store->count_statements( undef, undef, $litlang1, undef );
	  is( $count, 0, 'expected 0 language literal' );
	}

	my $quad3	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $litlang1, $ex->d);
	$store->add_statement( $quad3 );
	is( $store->size, 3, 'store has 3 statements after integer literal add' );

	my $triple2	= RDF::Trine::Statement->new($ex->a, $ex->b, $litstring);
	$store->add_statement( $triple2 );
	is( $store->size, 4, 'store has 4 statements after (triple) add' );

	{
	  my $count	= $store->count_statements( undef, undef, $litplain, undef );
	  is( $count, 1, 'expected 1 plain literal' );
	}
	{
	  my $count	= $store->count_statements( undef, undef, $litstring, undef );
	  is( $count, 1, 'expected 1 string literal' );
	}
	{
	  my $count	= $store->count_statements( undef, undef, $litstring, $ex->d );
	  is( $count, 0, 'expected 0 string literal with context' );
	}

	$store->remove_statement($quad);
	is( $store->size, 3, 'store has 3 statements after plain literal remove' );

	my $quad4	= RDF::Trine::Statement::Quad->new($ex->a, $ex->b, $litint, $ex->d);
	$store->add_statement( $quad4 );
	is( $store->size, 4, 'store has 4 statements after integer literal add' );

	{
	  my $count	= $store->count_statements( $ex->a, $ex->b, undef, undef);
	  is( $count, 4, 'expected 4 triples with all literals' );
	}

	{
	  my $count	= $store->count_statements( $ex->a, $ex->b, $litint, undef );
	  is( $count, 1, 'expected 1 triple with integer literal' );
	}

	{
	  my $count	= $store->count_statements( $ex->a, undef, $litlang1, undef );
	  is( $count, 1, 'expected 1 triple with language literal' );
	}


	$store->remove_statement($triple2);
	is( $store->size, 3, 'store has 2 statements after string literal remove' );

	$store->remove_statements(undef, undef, $litlang2, undef );
	is( $store->size, 2, 'expected 2 statements after language remove statements' );

	$store->remove_statements($ex->a, $ex->b, undef, undef );
	is( $store->size, 0, 'expected zero size after remove statements' );
}


=item C<< blank_node_tests_simple( $store, $data->{ex} )  >>

Tests to check blank node support.

=cut


sub blank_node_tests_simple {
	note "simple tests with blank nodes";
	my ($store, $ex) = @_;
	
	my $blankfoo    = RDF::Trine::Node::Blank->new('foo');
	my $blankbar    = RDF::Trine::Node::Blank->new('bar');
	my $triple	= RDF::Trine::Statement->new($blankfoo, $ex->b, $ex->c);
	my $quad	= RDF::Trine::Statement::Quad->new($blankfoo, $ex->b, $ex->c, $ex->d);
	$store->add_statement( $triple, $ex->d );
	is( $store->size, 1, 'store has 1 statement after (triple+context) add' );
	$store->add_statement( $quad );
	is( $store->size, 1, 'store has 1 statement after duplicate (quad) add' );
	$store->remove_statement( $triple, $ex->d );
	is( $store->size, 0, 'store has 0 statements after (triple+context) remove' );
	
	my $quad2	= RDF::Trine::Statement::Quad->new($blankbar, $ex->b, $ex->c, $ex->d);
	$store->add_statement( $quad2 );
	is( $store->size, 1, 'store has 1 statement after (quad) add' );
	$store->add_statement( $quad );
	is( $store->size, 2, 'store has 2 statements after (quad) add' );

	my $triple2	= RDF::Trine::Statement->new($ex->a, $ex->b, $blankfoo);
	$store->add_statement( $triple2 );
	is( $store->size, 3, 'store has 3 statements after (quad) add' );

	{
	  my $count	= $store->count_statements( undef, undef, undef, $ex->d );
	  is( $count, 2, 'expected count of specific-context statements' );
	}

	{
	  my $count	= $store->count_statements( undef, undef, $blankfoo, $ex->d );
	  is( $count, 0, 'expected zero of specific-context statements' );
	}

	{
	  my $count	= $store->count_statements( undef, undef, $blankfoo, undef );
	  is( $count, 1, 'expected one object blank node' );
	}

	{
	  my $count	= $store->count_statements( $blankbar, undef, $blankfoo, undef );
	  is( $count, 0, 'expected zero subject-object blank node' );
	}

	{
	  my $count	= $store->count_statements( $blankbar, undef, undef, undef );
	  is( $count, 1, 'expected one subject blank node' );
	}

	{
	  my $count	= $store->count_statements( $blankfoo, undef, undef, $ex->d );
	  is( $count, 1, 'expected one subject-context blank node' );
	}

	{
	  my $count	= $store->count_statements( $blankfoo, $ex->b, undef, undef );
	  is( $count, 1, 'expected one subject-predicate blank node' );
	}

	$store->remove_statements( undef, undef, $blankfoo, undef );
	is( $store->size, 2, 'expected two triples after remove statements' );
	
	$store->remove_statement( $quad2 );
	is( $store->size, 1, 'expected single triples after remove statement' );
	$store->remove_statement( $quad );
	is( $store->size, 0, 'expected zero size after remove statement' );
}


=item C<< count_statements_tests_simple( $store, $data->{ex} )  >>

Tests to check that counts are correct.

=cut

sub count_statements_tests_simple {
	note " simple count_statements tests";
	my ($store, $ex) = @_;
	
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


=item C<< count_statements_tests_quads( $store, $data->{ex} )  >>

Count statement tests for quads.


=cut


sub count_statements_tests_quads {
	note " quad count_statements tests";
	my ($store, $ex) = @_;
	{
		is( $store->count_statements, 27, 'count_statements()' );
		is( $store->count_statements(undef, undef, undef), 27, 'count_statements( fff )' );
		is( $store->count_statements(undef, undef, undef, undef), 81, 'count_statements( ffff )' );
		
		is( $store->count_statements( $ex->a, undef, undef ), 9, 'count_statements( bff )' );
		is( $store->count_statements( $ex->a, undef, undef, undef ), 27, 'count_statements( bfff )' );
		is( $store->count_statements( $ex->a, undef, undef, $ex->a ), 9, 'count_statements( bffb )' );
	}
}


=item C<<  count_statements_tests_triples( $store, $data->{ex}, $data->{nil} ) >>

More tests for counts, with triples.


=cut


sub count_statements_tests_triples {
	note " triple count_statements tests";
	my ($store, $ex, $nil) = @_;
	
	{
		is( $store->count_statements, 27, 'count_statements() after triples added' );
		is( $store->count_statements(undef, undef, undef), 27, 'count_statements( fff ) after triples added' );
		is( $store->count_statements(undef, undef, undef, undef), 108, 'count_statements( ffff ) after triples added' );
		
		is( $store->count_statements( $ex->a, undef, undef ), 9, 'count_statements( bff )' );
		is( $store->count_statements( $ex->a, undef, undef, undef ), 27+9, 'count_statements( bfff )' );
		is( $store->count_statements( $ex->a, undef, undef, $nil ), 9, 'count_statements( bffb )' );
	}
}


=item C<< get_statements_tests_triples( $store, $data->{ex} )  >>

Tests for getting statements using triples.

=cut


sub get_statements_tests_triples {
	note " triple get_statements tests";
	my ($store, $ex) = @_;
	
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


=item C<< get_statements_tests_quads( $store, $data->{ex}, $data->{nil}  )  >>

Tests for getting statements using quads.

=cut



sub get_statements_tests_quads {
	note " quad get_statements tests";
	my ($store, $ex, $nil) = @_;
	
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


=item C<< orderby_tests( $store );  >>

Orderby functionality is not yet implemented.

=cut


sub orderby_tests {
	note " orderby tests";
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


=item C<< remove_statement_tests( $store, $data->{ex}, @{$data->{names}} );  >>

Tests for removing statements.


=cut


sub remove_statement_tests {
	note " remove_statement tests";
	my ($store, $ex, @names) = @_;
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


1;
__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org> and Kjetil Kjernsmo <kjetilk@cpan.org>

=cut
