# RDF::Trine::Pattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Pattern - Class for basic graph patterns

=head1 VERSION

This document describes RDF::Trine::Pattern version 1.015

=cut

package RDF::Trine::Pattern;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);
use List::Util qw(any);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);
use RDF::Trine qw(iri);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.015';
}

######################################################################

=head1 METHODS

=over 4

=item C<< new ( @triples ) >>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my @triples	= @_;
	foreach my $t (@triples) {
		unless (blessed($t) and $t->isa('RDF::Trine::Statement')) {
			throw RDF::Trine::Error -text => "Patterns belonging to a BGP must be triples";
		}
	}
	return bless( [ @triples ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->triples);
}

=item C<< triples >>

Returns a list of triples belonging to this BGP.

=cut

sub triples {
	my $self	= shift;
	return @$self;
}

=item C<< type >>

=cut

sub type {
	return 'BGP';
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(bgp %s)',
		join(' ', map { $_->sse( $context ) } $self->triples)
	);
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->definite_variables } $self->triples);
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->triples );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->triples );
}

=item C<< subsumes ( $statement ) >>

Returns true if the pattern will subsume the $statement when matched against a
triple store.

=cut

sub subsumes {
	my $self	= shift;
	my $st		= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	my @triples	= $self->triples;
	foreach my $t (@triples) {
		if ($t->subsumes( $st )) {
			$l->debug($self->sse . " \x{2292} " . $st->sse);
			return 1;
		}
	}
	return 0;
}

=item C<< merge_patterns ( @patterns ) >>

Given an array of patterns, this will merge them into one.

=cut

sub merge_patterns {
	my ($class, @patterns) = @_;
	my @all_triples;
	foreach my $pattern (@patterns) {
		unless (blessed($pattern) and $pattern->isa('RDF::Trine::Pattern')) {
			throw RDF::Trine::Error -text => "Patterns to be merged must be patterns themselves";
		}
		push(@all_triples, $pattern->triples);
	}
	return $class->new(@all_triples);
}

=item C<< sort_for_join_variables >>

Returns a new pattern object with the subpatterns of the referrant
sorted based on heuristics that ensure firstly that patterns can be
joined on the same variable and secondly on the usual selectivity
(i.e. how quickly the engine can drill down to the answer) of triple
patterns. Calls C<< subgroup >>, C<< sort_triples >> and C<<
merge_patterns >> in that order.

=cut

sub sort_for_join_variables {
	my $self	= shift;
	return $self if (scalar $self->triples == 1);

	my $class	= ref($self);
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	$l->debug('Reordering ' . scalar $self->triples . ' triples for heuristical optimizations');

	my @sorted_triple_patterns = $self->subgroup;

	my @patterns;
	foreach my $pattern (@sorted_triple_patterns) {
		my $sorted = $pattern->sort_triples;
		push(@patterns, $sorted);
	}
	return $class->merge_patterns(@patterns);
}


=item C<< subgroup >>

Splits the pattern object up in an array of pattern objects where the
same triple patterns occur. It will group on common variables, so that
triple patterns can be joined together is in a group together. It will
also group triples that have no connection to other triples in a
group. It will then order the groups, first by number triples with
common variables, then by number of literals, then by the total number
of terms that are not variables.


=cut

sub subgroup {
	my $self = shift;
	my @triples = $self->triples;
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	my %structure_counts;
	my %triples_by_tid;
	# First, we loop the dataset to compile some numbers for the
	# variables in each triple pattern.  This is to break the pattern
	# into subpatterns that can be joined on the same variable
	foreach my $t (@triples) {
		my $tid = refaddr($t);
		$triples_by_tid{$tid}  = $t;
		my $not_variable = 0;
		foreach my $n ($t->nodes) {
			if ($n->isa('RDF::Trine::Node::Variable')) {
				my $name = $n->name;
				$structure_counts{ $name }{ 'name' } = $name; # TODO: Worth doing in an array?
				push(@{$structure_counts{$name}{'claimed_patterns'}}, $tid);
				$structure_counts{ $name }{ 'common_variable_count' }++;
				$structure_counts{ $name }{ 'not_variable_count' } = 0 unless ($structure_counts{ $name }{ 'not_variable_count' });
				$structure_counts{ $name }{ 'literal_count' } = 0 unless ($structure_counts{ $name }{ 'literal_count' });
				foreach my $char (split(//, $n->as_string)) { # TODO: Use a more standard format
					$structure_counts{ $name }{ 'string_sum' } += ord($char);
				}
				foreach my $o ($t->nodes) {
					unless ($o->isa('RDF::Trine::Node::Variable')) {
						$structure_counts{ $name }{ 'not_variable_count' }++;
					}
					elsif ($o->isa('RDF::Trine::Node::Literal')) {
						$structure_counts{ $name }{ 'literal_count' }++;
					}
				}
			} else {
				$not_variable++;
			}
		}
		if ($not_variable == 3) { # Then, there are no variables in the pattern
			my $name = '_no_definite';
			$structure_counts{ $name }{ 'not_variable_count' } = $not_variable;
			$structure_counts{ $name }{ 'common_variable_count' } = 0;
			$structure_counts{ $name }{ 'literal_count' } = 0; # Doesn't mean anything now
			$structure_counts{ $name }{ 'string_sum' } = 0; # Doesn't mean anything now
			push(@{$structure_counts{$name}{'claimed_patterns'}}, $tid);
		}

	}

	# Group triple subpatterns with just one triple pattern
	my $just_ones;
	while (my ($name, $data) = each(%structure_counts)) {
		if($data->{'common_variable_count'} <= 1) {
			$just_ones->{'common_variable_count'} = 1;
			$just_ones->{'string_sum'} = 1;
			$just_ones->{'literal_count'} += $data->{'literal_count'};
			$just_ones->{'not_variable_count'} += $data->{'not_variable_count'};
			my @claimed = @{$data->{'claimed_patterns'}};
			unless (any { $_ == $claimed[0] } @{$just_ones->{'claimed_patterns'}}) {
				push(@{$just_ones->{'claimed_patterns'}}, $claimed[0]);
			}
			delete $structure_counts{$name};
		}
	}

	$l->trace('Results of structural analysis: ' . Dumper(\%structure_counts));
	$l->trace('Block of single-triple patterns: ' . Dumper($just_ones));

	# Now, sort the patterns in the order specified by first the number
	# of occurances of common variables, then the number of literals
	# and then the number of terms that are not variables
	my @sorted_patterns = sort {     $b->{'common_variable_count'} <=> $a->{'common_variable_count'} 
											or $b->{'literal_count'}         <=> $a->{'literal_count'}
											or $b->{'not_variable_count'}    <=> $a->{'not_variable_count'}
											or $b->{'string_sum'}            <=> $a->{'string_sum'} 
										} values(%structure_counts);

	push (@sorted_patterns, $just_ones);

	my @sorted_triple_patterns;

	# Now, loop through the sorted patterns, let the one with most
	# weight first select the triples it wants to join.  Within those
	# subpatterns, apply the sort order of triple pattern heuristic
	foreach my $item (@sorted_patterns) {
		my @triple_patterns;
		my $triples_left = scalar keys(%triples_by_tid);
		if ($triples_left > 2) {
			foreach my $tid (@{$item->{'claimed_patterns'}}) {
				if (defined($triples_by_tid{$tid})) {
					push(@triple_patterns, $triples_by_tid{$tid});
					delete $triples_by_tid{$tid};
				}
			}
			$l->debug("There are $triples_left triples left");
			push(@sorted_triple_patterns, RDF::Trine::Pattern->new(@triple_patterns)); # TODO: Better way to call ourselves?
		} else {
			$l->debug("There is a rest of $triples_left triples");
			push(@sorted_triple_patterns, RDF::Trine::Pattern->new(values(%triples_by_tid)));
			last;
		}
	}

	return @sorted_triple_patterns;
}

=item C<< sort_triples >>

Will sort the triple patterns based on heuristics that looks at how
many variables the patterns have, and where they occur, see REFERENCES
for details. Returns a new sorted pattern object.

=cut

sub sort_triples {
	my $self = shift;
	return $self->_hsp_heuristic_1_4_triple_pattern_order;
}

sub _hsp_heuristic_1_4_triple_pattern_order { # Heuristic 1 and 4 of HSP
	my $self	= shift;
	my $class	= ref($self);
	my @triples	= @$self;
	return $self if (scalar @triples == 1);
	my %triples_by_tid;
	foreach my $t (@triples) {
		my $tid = refaddr($t);
		$triples_by_tid{$tid}{'tid'} = $tid; # TODO: Worth doing this in an array?
		$triples_by_tid{$tid}{'triple'} = $t;
		$triples_by_tid{$tid}{'sum'} = _hsp_heuristic_triple_sum($t);
	}
	my @sorted_tids = sort { $a->{'sum'} <=> $b->{'sum'} } values(%triples_by_tid);
	my @sorted_triples;
	foreach my $entry (@sorted_tids) {
		push(@sorted_triples, $triples_by_tid{$entry->{'tid'}}->{'triple'});
	}
	return $class->new(@sorted_triples);
}

# The below function finds a number to aid sorting
# It takes into account Heuristic 1 and 4 of the HSP paper, see REFERENCES
# as well as that it was noted in the text that rdf:type is usually less selective.

# By assigning the integers to nodes, depending on whether they are in
# triple (subject, predicate, object), variables, rdf:type and
# literals, and sum them, they may be sorted. See code for the actual
# values used.

# Denoting s for bound subject, p for bound predicate, a for rdf:type
# as predicate, o for bound object and l for literal object and ? for
# variable, we get the following order, most of which are identical to
# the HSP:

# spl: 6
# spo: 8
# sao: 10
# s?l: 14
# s?o: 16
# ?pl: 25
# ?po: 27
# sp?: 30
# sa?: 32
# ??l: 33
# ??o: 35
# s??: 38
# ?p?: 49
# ?a?: 51
# ???: 57

# Note that this number is not intended as an estimate of selectivity,
# merely a sorting key, but further research may possibly create such
# numbers.

sub _hsp_heuristic_triple_sum {
	my $t = shift;
	my $sum = 0;
	if ($t->subject->is_variable) {
		$sum = 20;
	} else {
		$sum = 1;
	}
	if ($t->predicate->is_variable) {
		$sum += 10;
	} else {
		if ($t->predicate->equal(iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'))) {
			$sum += 4;
		} else {
			$sum += 2;
		}
	}
	if ($t->object->is_variable) {
		$sum += 27;
	} elsif ($t->object->is_literal) {
		$sum += 3;
	} else {
		$sum += 5;
	}
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	# Now a trick to get an deterministic sort order, hard to test without.
	$sum *= 10000000;
	foreach my $c (split(//,$t->as_string)) {
		$sum += ord($c);
	}
	$l->debug($t->as_string . " triple has sorting sum " . $sum);
	return $sum;
}


	

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 REFERENCES

The heuristics to order triple patterns in this module is strongly
influenced by L<The ICS-FORTH Heuristics-based SPARQL Planner
(HSP)|http://www.ics.forth.gr/isl/index_main.php?l=e&c=645>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

Kjetil Kjernsmo C<< <kjetilk@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
