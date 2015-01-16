=head1 NAME

RDF::Trine::Store::Hexastore - RDF store implemented with the hexastore index

=head1 VERSION

This document describes RDF::Trine::Store::Hexastore version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Store::Hexastore;

=head1 DESCRIPTION

RDF::Trine::Store::Hexastore provides an in-memory triple-store based on
six-way indexing as popularized by Hexastore.

=cut

package RDF::Trine::Store::Hexastore;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Data::Dumper;
use RDF::Trine qw(iri);
use RDF::Trine::Error;
use List::Util qw(first);
use Scalar::Util qw(refaddr reftype blessed);
use Storable qw(nstore retrieve);
use Carp qw(croak);
use Time::HiRes qw ( time );
use Log::Log4perl;

use constant NODES		=> qw(subject predicate object);
use constant NODEMAP	=> { subject => 0, predicate => 1, object => 2, context => 3 };
use constant OTHERNODES	=> {
				subject		=> [qw(predicate object)],
				predicate	=> [qw(subject object)],
				object		=> [qw(subject predicate)],
			};

######################################################################

our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}

######################################################################

sub _config_meta {
	return {
		required_keys	=> [],
		fields			=> {},
	}
}


=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new () >>

Returns a new storage object.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Hexastore> for this backend.

This module also supports initializing the store from a file or URL,
in which case, a C<sources> key may be used. This holds an arrayref of
hashrefs.  To load a file, you may give the file name with a C<file>
key in the hashref, and to load a URL, use C<url>. See example
below. Furthermore, the following keys may be used:

=over

=item C<syntax>

The syntax of the parsed file or URL.

=item C<base_uri>

The base URI to be used for a parsed file.

=back

The following example initializes a Hexastore store based on a local file and a remote URL:

  my $store = RDF::Trine::Store->new_with_config( {
      storetype => 'Hexastore',
      sources => [
          {
              file => 'test-23.ttl',
              syntax => 'turtle',
          },
          {
              url => 'http://www.kjetil.kjernsmo.net/foaf',
              syntax => 'rdfxml',
          }
  ]});


=cut

sub new {
	my $class	= shift;
	my $self	= bless({}, $class);
	$self->nuke; # nuke resets the store, thus doing the same thing as init should do
	return $self;
}

sub _new_with_string {
	my ($self, $config) = @_;
	my ($filename) = $config =~ m/file=(.+)$/; # TODO: It has a Storable part too, for later use.
	return $self->load($filename);
}

# TODO: Refactor, almost identical to Memory
sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	my @sources = @{ $config->{sources} || [] };
	my $self	= $class->new();
	foreach my $source (@sources) {
		my %args;
		if (my $g = $source->{graph}) {
			$args{context}	= (blessed($g) ? $g : iri($g));
		}
		if ($source->{url}) {
			my $parser	= RDF::Trine::Parser->new($source->{syntax});
			my $model	= RDF::Trine::Model->new( $self );
			$parser->parse_url_into_model( $source->{url}, $model, %args );
		} elsif ($source->{file}) {
			open(my $fh, "<:encoding(UTF-8)", $source->{file}) || throw RDF::Trine::Error -text => "Couldn't open file $source->{file}";
			my $parser = RDF::Trine::Parser->new($source->{syntax});
			my $model	= RDF::Trine::Model->new( $self );
			$parser->parse_file_into_model( $source->{base_uri}, $source->{file}, $model, %args );
		} else {
			throw RDF::Trine::Error::MethodInvocationError -text => "$class needs a url or file argument";
		}
	}
	return $self;
}




=item C<< store ( $filename ) >>

Write the triples data to a file specified by C<< $filename >>.
This data may be read back in with the C<< load >> method.

=cut

sub store {
	my $self	= shift;
	my $fname	= shift;
	nstore( $self, $fname );
}

=item C<< load ( $filename ) >>

Returns a new Hexastore object with triples data from the specified file.

=cut

sub load {
	my $class	= shift;
	my $fname	= shift;
	return retrieve($fname);
}

=item C<< temporary_store >>

Returns a temporary (empty) triple store.

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
	my @nodes	= splice(@_, 0, 3);
	my $context	= shift;
	my %args	= @_;
	my @orderby	= (ref($args{orderby})) ? @{$args{orderby}} : ();
	
	if (defined($context) and not($context->isa('RDF::Trine::Node::Nil'))) {
		return RDF::Trine::Iterator::Graph->new( [] );
	}
	
	my $defined	= 0;
	my %variable_map;
	foreach my $i (0 .. 2) {
		my $node	= $nodes[ $i ];
		my $pos		= (NODES)[ $i ];
		$defined++ if (defined($node) and not($node->isa('RDF::Trine::Node::Variable')));
		if (blessed($node) and $node->isa('RDF::Trine::Node::Variable')) {
			$variable_map{ $node->name }	= $pos;
		}
	}
	
	my @ids		= map { $self->_node2id( $_ ) } @nodes;
	my @names	= NODES;
	my @keys	= map { $names[$_], $ids[$_] } (0 .. $#names);
	if ($defined == 3) {
		my $index	= $self->_index_from_pair( $self->_index_root, @keys[ 0,1 ] );
		my $list	= $self->_index_from_pair( $index, @keys[ 2,3 ] );
		if ($self->_page_contains_node( $list, $ids[2] )) {
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
		
		my $index	= $self->_index_from_pair( $self->_index_root, @keys[ 0,1 ] );
		my $list	= $self->_index_from_pair( $index, @keys[ 2,3 ] );
		
		my @local_list	= $self->_node_values( $list );
		my $sub		= sub {
			return unless (scalar(@local_list));
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
		
		my $rev	= 0;
		if (@orderby) {
			$rev	= 1 if ($orderby[1] eq 'DESC');
			my $sortkey	= $variable_map{ $orderby[0] };
			if ($sortkey ne $ukeys[0]) {
				@ukeys	= reverse(@ukeys);
			}
		}
		
		my $index	= $self->_index_from_pair( $self->_index_root, @keys );
		my $ukeys1	= $self->_index_values_from_key( $index, $ukeys[0] );
		my @ukeys1	= $self->_index_values( $ukeys1, $rev );

		my @local_list;
		my $ukey1;
		my $sub		= sub {
			while (0 == scalar(@local_list)) {
				return unless (scalar(@ukeys1));
				$ukey1		= shift(@ukeys1);
#				warn '>>>>>>>>> ' . Dumper( $ukeys[0], $ukey1, $data );
				my $list	= $self->_index_from_pair( $index, $ukeys[0], $ukey1 );
				@local_list	= $self->_node_values( $list );
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
		
		my $rev	= 0;
		my (@order_keys, $final_key);
		if (@orderby) {
			$rev	= 1 if ($orderby[1] eq 'DESC');
			my $sortkey	= $variable_map{ $orderby[0] };
			my @nodes	= ($sortkey, grep { $_ ne $sortkey } NODES);
			@order_keys	= @nodes[0,1];
			$final_key	= $nodes[2];
		} else {
			$final_key	= 'object';
			@order_keys	= qw(subject predicate);
		}
		if ($max > 1) {
			@order_keys	= @{ $dup_var_pos{ $dup_var } };
			my %order_keys	= map { $_ => 1 } @order_keys;
			if (3 == scalar(@order_keys)) {
				$final_key		= pop(@order_keys);
			} else {
				$final_key		= first { not($order_keys{ $_ }) } @names;
			}
		}
		
		my $subj	= $self->_index_values_from_key( $self->_index_root, $order_keys[0] );
		my @skeys	= $self->_index_values( $subj, $rev );
		my ($sid, $pid);
		my @pkeys;
		my @local_list;
		my $sub		= sub {
			while (0 == scalar(@local_list)) {
				# no more objects. go to next predicate.
				while (0 == scalar(@pkeys)) {
					# no more predicates. go to next subject.
	 				return unless (scalar(@skeys));
					$sid	= shift(@skeys);
# 					warn "*** using subject $sid\n";
					@pkeys	= sort { $a <=> $b } keys %{ $subj->{ $sid }{ $order_keys[1] } };
					if ($max >= 2) {
						@pkeys	= grep { $_ == $sid } @pkeys;
					}
				}
				$pid	= shift(@pkeys);
# 				warn "*** using predicate $pid\n";
				my $index	= $self->_index_from_pair( $subj, $sid, $order_keys[1] );
				my $list	= $self->_node_list_from_id( $index, $pid );
				@local_list	= $self->_node_values( $list );
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
	if ($bgp->isa('RDF::Trine::Pattern')) {
		$bgp	= $bgp->sort_for_join_variables();
	}
	my @triples	= $bgp->triples;
	if (2 == scalar(@triples)) {
		my ($t1, $t2)	= @triples;
		my @v1	= $t1->referenced_variables;
		my %v1	= map { $_ => 1 } @v1;
		my @v2	= $t2->referenced_variables;
		my @shared	= grep { exists($v1{$_}) } @v2;
		if (@shared) {
# 			warn 'there is a shared variable -- we can use a merge-join';
			# there is a shared variable -- we can use a merge-join
			my $shrkey	= $shared[0];
# 			warn "- $shrkey\n";
# 			warn $t2->as_string;
			my $i1	= $self->SUPER::_get_pattern( RDF::Trine::Pattern->new( $t1 ), undef, orderby => [ $shrkey => 'ASC' ] );
			my $i2	= $self->SUPER::_get_pattern( RDF::Trine::Pattern->new( $t2 ), undef, orderby => [ $shrkey => 'ASC' ] );
			
			my $i1current	= $i1->next;
			my $i2current	= $i2->next;
			my @results;
			while (defined($i1current) and defined($i2current)) {
				my $i1cur	= $i1current->{ $shrkey };
				my $i2cur	= $i2current->{ $shrkey };
				if ($i1current->{ $shrkey }->equal( $i2current->{ $shrkey } )) {
					my @matching_i2_rows;
					my $match_value	= $i1current->{ $shrkey };
					while ($match_value->equal( $i2current->{ $shrkey } )) {
						push( @matching_i2_rows, $i2current );
						unless ($i2current = $i2->next) {
#							warn "no more from i2";
							last;
						}
					}
					
					while ($match_value->equal( $i1current->{ $shrkey } )) {
						foreach my $i2_row (@matching_i2_rows) {
							my $new	= $self->_join( $i1current, $i2_row );
							push( @results, $new );
						}
						unless ($i1current = $i1->next) {
#							warn "no more from i1";
							last;
						}
					}
				} elsif ($i1current->{ $shrkey }->compare( $i2current->{ $shrkey } ) == -1) {
					my $i1v	= $i1current->{ $shrkey };
					my $i2v	= $i2current->{ $shrkey };
# 					warn "keys don't match: $i1v <=> $i2v\n";
					$i1current	= $i1->next;
				} else { # ($i1current->{ $shrkey } > $i2current->{ $shrkey })
					my $i1v	= $i1current->{ $shrkey };
					my $i2v	= $i2current->{ $shrkey };
# 					warn "keys don't match: $i1v <=> $i2v\n";
					$i2current	= $i2->next;
				}
			}
			return RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
		} else {
			my $l		= Log::Log4perl->get_logger("rdf.trine.store.hexastore");
			$l->info('No shared variable -- cartesian product');
			# no shared variable -- cartesian product
			my $i1	= $self->SUPER::_get_pattern( RDF::Trine::Pattern->new( $t1 ) );
			my $i2	= $self->SUPER::_get_pattern( RDF::Trine::Pattern->new( $t2 ) );
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
		return $self->SUPER::_get_pattern( $bgp );
	}
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	return;
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
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.hexastore");
	$l->warn("Contexts not supported for the Hexastore store");
 	return RDF::Trine::Iterator->new([]);
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $added	= 0;

	# believe it or not, these calls add up.
	my %stmt = map { $_ => $st->$_ } NODES;
	my %ids  = map { $_ => $self->_node2id($stmt{$_}) } NODES;

	foreach my $first (NODES) {
		my $firstnode	= $stmt{$first};
		my $id1			= $ids{$first};
		my @others		= @{ OTHERNODES->{ $first } };
		my @orders		= ([@others], [reverse @others]);
		foreach my $order (@orders) {
			my ($second, $third)	= @$order;
			my ($id2, $id3) = @ids{$second, $third};
			my $list	= $self->_get_terminal_list( $first => $id1, $second => $id2 );
			if ($self->_add_node_to_page( $list, $id3 )) {
				$added++;
			}
		}
	}
	if ($added) {
		$self->{ size }++;
		$self->{etag} = time;
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
			if ($self->_remove_node_from_page( $list, $id3 )) {
				$removed++;
			}
# 			warn "removing $first-$second-$third $id1-$id2-$id3 from list [" . join(', ', @$list) . "]\n";
# 			warn "\t- remaining: [" . join(', ', @$list) . "]\n";
		}
	}

	if ($removed) {
		$self->{ size }--;
		$self->{etag} = time;
	}
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=item C<< etag >>

Returns an Etag suitable for use in an HTTP Header.

=cut

sub etag {
	return $_[0]->{etag};
}


=item C<< nuke >>

Permanently removes all the data in the store.

=cut

sub nuke {
	my $self = shift;
	$self->{data} = $self->_new_index_page;
	$self->{node2id} = {};
	$self->{id2node} = {};
	$self->{next_id} = 1;
	$self->{size} = 0;
	$self->{etag} = time;
	return $self;
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
	my @keys	= map { $names[$_], $ids[$_] } (0 .. $#names);
	my @dkeys;
	my @ukeys;
	
	if (scalar(@nodes) > 3 and defined($nodes[3]) and not($nodes[3]->isa('RDF::Trine::Node::Nil'))) {
		return 0;
	}
	
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
		my $index	= $self->_index_from_pair( $self->_index_root, @keys );
		return $self->_count_statements( $index, @ukeys );
	} elsif (4 == scalar(@keys)) {
		my $index	= $self->_index_from_pair( $self->_index_root, @keys[ 0,1 ] );
		my $list	= $self->_index_from_pair( $index, @keys[ 2,3 ] );
		return $self->_node_count( $list );
	} else {
		my $index	= $self->_index_from_pair( $self->_index_root, @keys[ 0,1 ] );
		my $list	= $self->_index_from_pair( $index, @keys[ 2,3 ] );
		return ($self->_page_contains_node( $list, $keys[5] ))
			? 1
			: 0;
	}
}

sub _count_statements {
	my $self	= shift;
	my $data	= shift;
	my @ukeys	= @_;
	if (1 >= scalar(@ukeys)) {
		return $self->_node_count( $data );
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
	return unless (blessed($node));
	return if ($node->isa('RDF::Trine::Node::Variable'));

	# this gets called so much it actually significantly impacts run
	# time. call it once per invocation of _node2id instead of twice.
	my $str = $node->as_string;
	my $id = $self->{ node2id }{ $str };

	if (defined $id) {
		return $id;
	} else {
		$id	= ($self->{ node2id }{ $str } = $self->{ next_id }++);
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
		return;
	}
}

sub _seen_nodes {
	my $self	= shift;
	return values %{ $self->{ id2node } };
}

################################################################################
### The methods below are the only ones that directly access and manipulate the
### index structure. The terminal node lists, however, are manipulated by other
### methods (add_statement, remove_statement, etc.).

sub _index_root {
	my $self	= shift;
	return $self->{'data'};
}

sub _get_terminal_list {
	my $self	= shift;
	my $first	= shift;
	my $id1		= shift;
	my $second	= shift;
	my $id2		= shift;
	my $index	= $self->_index_from_pair( $self->_index_root, $first, $id1 );
	my $page	= $self->_index_from_pair( $index, $second, $id2 );
	if (ref($page)) {
		return $page;
	} else {
		my ($k1, $k2)	= sort { $a->[0] cmp $b->[0] } ([$first, $id1], [$second, $id2]);
		my $index	= $self->_index_from_pair( $self->_index_root, $k1->[0], $k1->[1] );
		unless ($index) {
			$index	= $self->_add_index_page( $self->_index_root, $k1->[0], $k1->[1] );
		}
		
		my $list	= $self->_index_from_pair( $index, $k2->[0], $k2->[1] );
		unless ($list) {
			$list	= $self->_add_list_page( $index, $k2->[0], $k2->[1] );
		}
		
		###
		
		my $index2	= $self->_index_from_pair( $self->_index_root, $k2->[0], $k2->[1] );
		unless ($index2) {
			$index2	= $self->_add_index_page( $self->_index_root, $k2->[0], $k2->[1] );
		}
		$self->_add_list_page( $index2, $k1->[0], $k1->[1], $list );
		return $list;
	}
}

#########################################
#########################################
#########################################
sub _add_list_page {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $value	= shift;
	my $list	= shift || $self->_new_list_page;
	$index->{ $key }{ $value }	= $list;
}

sub _add_index_page {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $value	= shift;
	$index->{ $key }{ $value }	= $self->_new_index_page;
}

sub _index_from_pair {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	my $val		= shift;
	return $index->{ $key }{ $val };
}

sub _node_list_from_id {
	my $self	= shift;
	my $index	= shift;
	my $id		= shift;
	return $index->{ $id };
}

sub _index_values_from_key {
	my $self	= shift;
	my $index	= shift;
	my $key		= shift;
	return $index->{ $key };
}

sub _index_values {
	my $self	= shift;
	my $index	= shift;
	my $rev		= shift;
	if ($rev) {
		my @values	= sort { $b <=> $a } keys %$index;
		return @values;
	} else {
		my @values	= sort { $a <=> $b } keys %$index;
		return @values;
	}
}
#########################################
#########################################
#########################################

sub _node_count {
	my $self	= shift;
	my $list	= shift;
	return scalar(@{ $list || [] });
}

sub _node_values {
	my $self	= shift;
	my $list	= shift;
	if (ref($list)) {
		return @$list;
	} else {
		return;
	}
}

sub _page_contains_node {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	foreach (@$list) {
		return 1 if ($_ == $id);
	}
	return 0;
}

sub _add_node_to_page {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	if ($self->_page_contains_node( $list, $id )) {
		return 0;
	} else {
		@$list	= sort { $a <=> $b } (@$list, $id);
		return 1;
	}
}

sub _remove_node_from_page {
	my $self	= shift;
	my $list	= shift;
	my $id		= shift;
	if ($self->_page_contains_node( $list, $id )) {
		@$list	= grep { $_ != $id } @$list;
		return 1;
	} else {
		return 0;
	}
}

sub _new_index_page {
	return { __type => 'index' };
}

sub _new_list_page {
	return [];
}

################################################################################

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
