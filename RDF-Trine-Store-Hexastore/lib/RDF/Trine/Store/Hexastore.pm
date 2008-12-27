=head1 NAME

RDF::Trine::Store::Hexastore - RDF store implemented with the hexastore index

=head1 VERSION

This document describes RDF::Trine::Store::Hexastore version 0.100


=head1 SYNOPSIS

    use RDF::Trine::Store::Hexastore;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.

=cut

package RDF::Trine::Store::Hexastore;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

our $VERSION	= 0.100;

use Data::Dumper;
use RDF::Trine::Error;
use List::Util qw(first);
use List::MoreUtils qw(any mesh);
use Scalar::Util qw(refaddr reftype blessed);
use Storable qw(nstore retrieve);

use constant NODES		=> qw(subject predicate object);
use constant NODEMAP	=> { subject => 0, predicate => 1, object => 2, context => 3 };
use constant OTHERNODES	=> {
				subject		=> [qw(predicate object)],
				predicate	=> [qw(subject object)],
				object		=> [qw(subject predicate)],
			};

=head1 METHODS

=over 4

=item C<< new () >>

Returns a new storage object using the supplied arguments to construct a DBI
object for the underlying database.

=cut

sub new {
	my $class	= shift;
	my $self	= bless({
		data		=> $class->new_index_page,
		node2id		=> {},
		id2node		=> {},
		next_id		=> 1,
		size		=> 0,
	}, $class);
	return $self;
}

sub store {
	my $self	= shift;
	my $fname	= shift;
	nstore( $self, $fname );
}

sub load {
	my $class	= shift;
	my $fname	= shift;
	return retrieve($fname);
}

=item C<< temporary_store >>

=cut

sub temporary_store {
	my $class	= shift;
	return $class->new();
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..2];
	my $defined	= 0;
	foreach my $node (@nodes) {
		$defined++ if (defined($node) and not($node->isa('RDF::Trine::Node::Variable')));
	}
	
	my @ids		= map { $self->_node2id( $_ ) } @nodes;
	my @names	= NODES;
	my @keys	= mesh @names, @ids;
	if ($defined == 3) {
		my $index	= $self->index_from_pair( $self->index_root, @keys[ 0,1 ] );
		my $list	= $self->index_from_pair( $index, @keys[ 2,3 ] );
# 		if (any { $_ == $ids[2] } @$list) {
		if ($self->page_contains_node( $list, $ids[2] )) {
			return RDF::Trine::Iterator::Graph->new( [ RDF::Trine::Statement->new( @nodes ) ] );
		} else {
			return RDF::Trine::Iterator::Graph->new( [] );
		}
	} elsif ($defined == 2) {
		my @dkeys;
		my $ukey;
		foreach my $i (0 .. 2) {
			if (defined($nodes[ $i ]) and not($nodes[ $i ]->isa('RDF::Trine::Node::Variable'))) {
				push( @dkeys, $names[$i] );
			} else {
				$ukey	= $names[$i];
			}
		}
		@keys	= map { $_ => $self->_node2id( $nodes[ NODEMAP->{ $_ } ] ) } @dkeys;
		
		my $index	= $self->index_from_pair( $self->index_root, @keys[ 0,1 ] );
		my $list	= $self->index_from_pair( $index, @keys[ 2,3 ] );
		
		my @local_list	= $self->node_values( $list );
		my $sub		= sub {
			return undef unless (scalar(@local_list));
			my $id	= shift(@local_list);
			my %data	= map { $_ => $nodes[ NODEMAP->{ $_ } ] } @dkeys;
			$data{ $ukey }	= $self->_id2node( $id );
			my $st	= RDF::Trine::Statement->new( @data{qw(subject predicate object)} );
			return $st;
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	} elsif ($defined == 1) {
		my $dkey;
		my @ukeys;
		my $uvar;
		my $check_dup	= 0;
		foreach my $i (0 .. 2) {
			if (defined($nodes[ $i ]) and not($nodes[ $i ]->isa('RDF::Trine::Node::Variable'))) {
				$dkey	= $names[$i];
			} else {
				if (blessed($nodes[ $i ]) and $nodes[ $i ]->isa('RDF::Trine::Node::Variable')) {
					if (defined($uvar)) {
						if ($uvar eq $nodes[ $i ]->name) {
							$check_dup	= 1;
						}
					} else {
						$uvar	= $nodes[ $i ]->name;
					}
				}
				push( @ukeys, $names[$i] );
			}
		}
		@keys		= ($dkey => $self->_node2id( $nodes[ NODEMAP->{ $dkey } ] ));
		
		my $index	= $self->index_from_pair( $self->index_root, @keys );
		my $ukeys1	= $self->index_values_from_key( $index, $ukeys[0] );
		my @ukeys1	= $self->index_values( $ukeys1 );
		
		my @local_list;
		my $ukey1;
		my $sub		= sub {
			while (0 == scalar(@local_list)) {
 				return undef unless (scalar(@ukeys1));
				$ukey1		= shift(@ukeys1);
#				warn '>>>>>>>>> ' . Dumper( $ukeys[0], $ukey1, $data );
				my $list	= $self->index_from_pair( $index, $ukeys[0], $ukey1 );
				@local_list	= $self->node_values( $list );
				if ($check_dup) {
					@local_list	= grep { $_ == $ukey1 } @local_list;
				}
			}
			my $id	= shift(@local_list);
			my %data	= ($dkey => $nodes[ NODEMAP->{ $dkey } ]);
			@data{ @ukeys }	= map { $self->_id2node( $_ ) } ($ukey1, $id);
			my $st	= RDF::Trine::Statement->new( @data{qw(subject predicate object)} );
			return $st;
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	} else {
		my $dup_pos;
		my $dup_var;
		my %dup_counts;
		my %dup_var_pos;
		my $max	= 0;
		foreach my $i (0 .. 2) {
			if (blessed($nodes[ $i ]) and $nodes[ $i ]->isa('RDF::Trine::Node::Variable')) {
				my $name	= $nodes[ $i ]->name;
				push( @{ $dup_var_pos{ $name } }, $names[ $i ] );
				if (++$dup_counts{ $name } > $max) {
					$max	= $dup_counts{ $name };
					$dup_pos	= $names[ $i ];
					$dup_var	= $name;
				}
			}
		}
# 		warn Dumper($dup_pos, $dup_var, $max, \%dup_var_pos);
		
		my $final_key	= 'object';
		my @order_keys	= qw(subject predicate);
		if ($max > 1) {
			@order_keys	= @{ $dup_var_pos{ $dup_var } };
			my %order_keys	= map { $_ => 1 } @order_keys;
			if (3 == scalar(@order_keys)) {
				$final_key		= pop(@order_keys);
			} else {
				$final_key		= first { not($order_keys{ $_ }) } @names;
			}
		}
# 		warn '========> ' . Dumper(\@order_keys, $final_key);
		
		my $subj	= $self->index_values_from_key( $self->index_root, $order_keys[0] );
		my @skeys	= $self->index_values( $subj );
		my ($sid, $pid);
		my @pkeys;
		my @local_list;
		my $sub		= sub {
			while (0 == scalar(@local_list)) {
				# no more objects. go to next predicate.
				while (0 == scalar(@pkeys)) {
					# no more predicates. go to next subject.
	 				return undef unless (scalar(@skeys));
					$sid	= shift(@skeys);
# 					warn "*** using subject $sid\n";
					@pkeys	= sort { $a <=> $b } keys %{ $subj->{ $sid }{ $order_keys[1] } };
					if ($max >= 2) {
						@pkeys	= grep { $_ == $sid } @pkeys;
					}
				}
				$pid	= shift(@pkeys);
# 				warn "*** using predicate $pid\n";
				my $index	= $self->index_from_pair( $subj, $sid, $order_keys[1] );
				my $list	= $self->node_list_from_id( $index, $pid );
				@local_list	= $self->node_values( $list );
				if ($max == 3) {
					@local_list	= grep { $_ == $pid } @local_list;
				}
# 				warn "---> object list: [" . join(', ', @local_list) . "]\n";
			}
			my $id	= shift(@local_list);
			my %data	= (
				$order_keys[0]	=> $sid,
				$order_keys[1]	=> $pid,
				$final_key		=> $id,
			);
			my @nodes	= map { $self->_id2node( $_ ) } (@data{qw(subject predicate object)});
			my $st	= RDF::Trine::Statement->new( @nodes );
			return $st;
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	}
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my @triples	= $bgp->triples;
	if (2 == scalar(@triples)) {
		my ($t1, $t2)	= @triples;
		my @v1	= $t1->referenced_variables;
		my %v1	= map { $_ => 1 } @v1;
		my @v2	= $t2->referenced_variables;
		my @shared	= grep { exists($v1{$_}) } @v2;
		if (@shared) {
			# there is a shared variable -- we can use a merge-join
			my $shrkey	= $shared[0];
			my $i1	= $self->SUPER::get_pattern( RDF::Trine::Pattern->new( $t1 ), undef, orderby => [ $shrkey => 'ASC' ] );
			my $i2	= $self->SUPER::get_pattern( RDF::Trine::Pattern->new( $t2 ), undef, orderby => [ $shrkey => 'ASC' ] );
			$i1->next;
			$i2->next;
			
			my @results;
			while (not($i1->finished) and not($i2->finished)) {
				my $i1cur	= $i1->current->{ $shrkey };
				my $i2cur	= $i2->current->{ $shrkey };
				if ($i1->current->{ $shrkey } == $i2->current->{ $shrkey }) {
					my @matching_i2_rows;
					my $match_value	= $i1->current->{ $shrkey };
					while ($match_value == $i2->current->{ $shrkey }) {
						push( @matching_i2_rows, $i2->current );
						last unless($i2->next);
					}
					
					while ($match_value == $i1->current->{ $shrkey }) {
						foreach my $i2_row (@matching_i2_rows) {
							push( @results, $self->_join( $i1->current, $i2_row ) );
						}
						last unless ($i1->next);
					}
				} elsif ($i1->current->{ $shrkey } < $i2->current->{ $shrkey }) {
					$i1->next;
				} else { # ($i1->current->{ $shrkey } > $i2->current->{ $shrkey })
					$i2->next;
				}
			}
			return RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
		} else {
			# no shared variable -- cartesian product
			my $i1	= $self->SUPER::get_pattern( RDF::Trine::Pattern->new( $t1 ) );
			my $i2	= $self->SUPER::get_pattern( RDF::Trine::Pattern->new( $t2 ) );
			my @i1;
			while (my $row = $i1->next) {
				push(@i1, $row);
			}
			
			my @results;
			while (my $row2 = $i2->next) {
				foreach my $row1 (@i1) {
					push(@results, { %$row1, %$row2 });
				}
			}
			return RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
		}
	} else {
		return $self->SUPER::get_pattern( $bgp );
	}
}

sub _join {
	my $self	= shift;
	my $rowa	= shift;
	my $rowb	= shift;
	
	my %keysa;
	my @keysa	= keys %$rowa;
	@keysa{ @keysa }	= (1) x scalar(@keysa);
	my @shared	= grep { exists $keysa{ $_ } } (keys %$rowb);
	foreach my $key (@shared) {
		my $val_a	= $rowa->{ $key };
		my $val_b	= $rowb->{ $key };
		next unless (defined($val_a) and defined($val_b));
		my $equal	= $val_a->equal( $val_b );
		unless ($equal) {
			return;
		}
	}
	
	my $row	= { (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
	return $row;
}

=item C<< get_contexts >>

=cut

sub get_contexts {
	die;
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $added	= 0;
	foreach my $first (NODES) {
		my $firstnode	= $st->$first();
		my $id1			= $self->_node2id( $firstnode );
		my @others		= @{ OTHERNODES->{ $first } };
		my @orders		= ([@others], [reverse @others]);
		foreach my $order (@orders) {
			my ($second, $third)	= @$order;
			my ($id2, $id3)	= map { $self->_node2id( $st->$_() ) } ($second, $third);
			my $list	= $self->_get_terminal_list( $first => $id1, $second => $id2 );
			if ($self->add_node_to_page( $list, $id3 )) {
				$added++;
			}
		}
	}
	if ($added) {
		$self->{ size }++;
	}
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my @ids		= map { $self->_node2id( $st->$_() ) } NODES;
# 	warn "*** removing statement @ids\n";
	
	my $removed	= 0;
	foreach my $first (NODES) {
		my $firstnode	= $st->$first();
		my $id1			= $self->_node2id( $firstnode );
		my @others		= @{ OTHERNODES->{ $first } };
		my @orders		= ([@others], [reverse @others]);
		foreach my $order (@orders) {
			my ($second, $third)	= @$order;
			my ($id2, $id3)	= map { $self->_node2id( $st->$_() ) } ($second, $third);
			my $list	= $self->_get_terminal_list( $first => $id1, $second => $id2 );
			if ($self->remove_node_from_page( $list, $id3 )) {
				$removed++;
			}
# 			warn "removing $first-$second-$third $id1-$id2-$id3 from list [" . join(', ', @$list) . "]\n";
# 			warn "\t- remaining: [" . join(', ', @$list) . "]\n";
		}
	}
	
	if ($removed) {
		$self->{ size }--;
	}
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	die;
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_;
	my @ids		= map { $self->_node2id( $_ ) } @nodes;
	my @names	= NODES;
	my @keys	= mesh @names, @ids;
	my @dkeys;
	my @ukeys;
	foreach my $i (0 .. 2) {
		if (defined($nodes[ $i ])) {
			push( @dkeys, $names[$i] );
		} else {
			push( @ukeys, $names[$i] );
		}
	}
	@keys		= map { $_ => $self->_node2id( $nodes[ NODEMAP->{ $_ } ] ) } @dkeys;
	if (0 == scalar(@keys)) {
		return $self->{ size };
	} elsif (2 == scalar(@keys)) {
		my $index	= $self->index_from_pair( $self->index_root, @keys );
		return $self->_count_statements( $index, @ukeys );
	} elsif (4 == scalar(@keys)) {
		my $index	= $self->index_from_pair( $self->index_root, @keys[ 0,1 ] );
		my $list	= $self->index_from_pair( $index, @keys[ 2,3 ] );
		return $self->node_count( $list );
	} else {
		my $index	= $self->index_from_pair( $self->index_root, @keys[ 0,1 ] );
		my $list	= $self->index_from_pair( $index, @keys[ 2,3 ] );
		return ($self->page_contains_node( $list, $keys[5] ))	# any { $_ == $keys[5] } @$list)
			? 1
			: 0;
	}
}

sub _count_statements {
	my $self	= shift;
	my $data	= shift;
	my @ukeys	= @_;
	if (1 >= scalar(@ukeys)) {
		return $self->node_count( $data );
	} else {
		my $count	= 0;
		my $ukey	= shift(@ukeys);
		my $data	= $data->{ $ukey };
		foreach my $k (keys %$data) {
			$count	+= $self->_count_statements( $data->{ $k }, @ukeys );
		}
		return $count;
	}
}

sub _node2id {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef if ($node->isa('RDF::Trine::Node::Variable'));
	if (exists( $self->{ node2id }{ $node->as_string } )) {
		return $self->{ node2id }{ $node->as_string };
	} else {
		my $id	= ($self->{ node2id }{ $node->as_string } = $self->{ next_id }++);
		$self->{ id2node }{ $id }	= $node;
		return $id
	}
}

sub _id2node {
	my $self	= shift;
	my $id		= shift;
	if (exists( $self->{ id2node }{ $id } )) {
		return $self->{ id2node }{ $id };
	} else {
		return undef;
	}
}


################################################################################
### The methods below are the only ones that directly access and manipulate the
### index structure. The terminal node lists, however, are manipulated by other
### methods (add_statement, remove_statement, etc.).

sub index_root {
	my $self	= shift;
	return $self->{'data'};
}

sub _get_terminal_list {
	my $self	= shift;
	my $first	= shift;
	my $id1		= shift;
	my $second	= shift;
	my $id2		= shift;
	my $index	= $self->index_from_pair( $self->index_root, $first, $id1 );
	my $page	= $self->index_from_pair( $index, $second, $id2 );
	if (ref($page)) {
		return $page;
	} else {
		my ($k1, $k2)	= sort { $a->[0] cmp $b->[0] } ([$first, $id1], [$second, $id2]);
		my $index	= $self->index_from_pair( $self->index_root, $k1->[0], $k1->[1] );
		unless ($index) {
			$index	= $self->add_index_page( $self->index_root, $k1->[0], $k1->[1] );
		}
		
		my $list	= $self->index_from_pair( $index, $k2->[0], $k2->[1] );
		unless ($list) {
			$list	= $self->add_list_page( $index, $k2->[0], $k2->[1] );
		}
		
		###
		
		my $index2	= $self->index_from_pair( $self->index_root, $k2->[0], $k2->[1] );
		unless ($index2) {
			$index2	= $self->add_index_page( $self->index_root, $k2->[0], $k2->[1] );
		}
		$self->add_list_page( $index2, $k1->[0], $k1->[1], $list );
		return $list;
	}
}

#########################################
#########################################
#########################################
sub add_list_page {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $value	= shift;
	my $list	= shift || $self->new_list_page;
	$index->{ $key }{ $value }	= $list;
}

sub add_index_page {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $value	= shift;
	$index->{ $key }{ $value }	= $self->new_index_page;
}

sub index_from_pair {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $val		= shift;
	return $index->{ $key }{ $val };
}

sub node_list_from_id {
	my $self	= shift;
	my $index	= shift;
	my $id		= shift;
	return $index->{ $id };
}

sub index_values_from_key {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	return $index->{ $key };
}

sub index_values {
	my $self	= shift;
	my $index	= shift;
	return sort { $a <=> $b } keys %$index;
}
#########################################
#########################################
#########################################

sub node_count {
	my $self	= shift;
	my $list	= shift;
	return scalar(@{ $list || [] });
}

sub node_values {
	my $self	= shift;
	my $list	= shift;
	if (ref($list)) {
		return @$list;
	} else {
		return;
	}
}

sub page_contains_node {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	return (any { $_ == $id } @$list) ? 1 : 0;
}

sub add_node_to_page {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	if ($self->page_contains_node( $list, $id )) {
		return 0;
	} else {
		@$list	= sort { $a <=> $b } (@$list, $id);
		return 1;
	}
}

sub remove_node_from_page {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	if ($self->page_contains_node( $list, $id )) {
		@$list	= grep { $_ != $id } @$list;
		return 1;
	} else {
		return 0;
	}
}

sub new_index_page {
	return { __type => 'index' };
}

sub new_list_page {
	return [];
}

################################################################################

1;

__END__
