# RDF::Trine::Iterator::Bindings
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Bindings - Iterator class for bindings query results

=head1 VERSION

This document describes RDF::Trine::Iterator::Bindings version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Iterator::Bindings;
 
 my $iterator = RDF::Trine::Iterator::Bindings->new( \&data, \@names );
 while (my $row = $iterator->next) {
   # $row is a HASHref containing variable name -> RDF Term bindings
   my @vars = keys %$row;
   print $row->{ 'var' }->as_string;
 }

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Iterator> class.

=over 4

=cut

package RDF::Trine::Iterator::Bindings;

use utf8;
use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

use JSON 2.0;
use Text::Table;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator::Bindings::Materialized;
use RDF::Trine::Serializer::Turtle;

use RDF::Trine::Iterator qw(smap);
use base qw(RDF::Trine::Iterator);

use Carp qw(croak);

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=item C<new ( \@results, \@names, %args )>

=item C<new ( \&results, \@names, %args )>

Returns a new SPARQL Result interator object. Results must be either
a reference to an array containing results or a CODE reference that
acts as an iterator, returning successive items when called, and
returning undef when the iterator is exhausted.

=cut

sub new {
	my $class	= shift;
	my $stream	= shift || sub { undef };
	my $names	= shift || [];
	my %args	= @_;
	
	my $type	= 'bindings';
	my $self	= $class->SUPER::new( $stream, $type, $names, %args );
	
	my $s 	= $args{ sorted_by } || [];
	$self->{sorted_by}	= $s;
	return $self;
}

sub _new {
	my $class	= shift;
	my $stream	= shift;
	my $type	= shift;
	my $names	= shift;
	my %args	= @_;
	return $class->new( $stream, $names, %args );
}

=item C<< materialize >>

Returns a materialized version of the current binding iterator.
The materialization process will leave this iterator empty. The materialized
iterator that is returned should be used for any future need for the iterator's
data.

=cut

sub materialize {
	my $self	= shift;
	my @data	= $self->get_all;
	my @args	= $self->construct_args;
	return $self->_mclass->_new( \@data, @args );
}

sub _mclass {
	return 'RDF::Trine::Iterator::Bindings::Materialized';
}

=item C<< project ( @columns ) >>

Returns a new stream that projects the current bindings to only the given columns.

=cut

sub project {
	my $self	= shift;
	my $class	= ref($self);
	my @proj	= @_;
	
	my $sub		= sub {
		my $row	= $self->next;
		return unless ($row);
		my $p	= { map { $_ => $row->{ $_ } } @proj };
		return $p;
	};
	
	my $args	= $self->_args();
	my $proj	= $class->new( $sub, [@proj], %$args );
	return $proj;
}

=item C<join_streams ( $stream, $stream )>

Performs a natural, nested loop join of the two streams, returning a new stream
of joined results.

=cut

sub join_streams {
	my $self	= shift;
	my $a		= shift;
	my $b		= shift;
# 	my $bridge	= shift;
	my %args	= @_;
	
# 	Carp::confess unless ($a->isa('RDF::Trine::Iterator::Bindings'));
# 	Carp::confess unless ($b->isa('RDF::Trine::Iterator::Bindings'));
	my $l		= Log::Log4perl->get_logger("rdf.trine.iterator.bindings");
	
	my @join_sorted_by;
	if (my $o = $args{ orderby }) {
		my $req_sort	= join(',', map { $_->[1]->name => $_->[0] } @$o);
		my $a_sort		= join(',', $a->sorted_by);
		my $b_sort		= join(',', $b->sorted_by);
		
		if ($l->is_debug) {
			$l->debug('---------------------------');
			$l->debug('REQUESTED SORT in JOIN: ' . Dumper($req_sort));
			$l->debug('JOIN STREAM SORTED BY: ' . Dumper($a_sort));
			$l->debug('JOIN STREAM SORTED BY: ' . Dumper($b_sort));
		}
		my $actual_sort;
		if (substr( $a_sort, 0, length($req_sort) ) eq $req_sort) {
			$l->debug("first stream is already sorted. using it in the outer loop.");
		} elsif (substr( $b_sort, 0, length($req_sort) ) eq $req_sort) {
			$l->debug("second stream is already sorted. using it in the outer loop.");
			($a,$b)	= ($b,$a);
		} else {
			my $a_common	= join('!', $a_sort, $req_sort);
			my $b_common	= join('!', $b_sort, $req_sort);
			if ($a_common =~ qr[^([^!]+)[^!]*!\1]) {	# shared prefix between $a_sort and $req_sort?
				$l->debug("first stream is closely sorted ($1).");
			} elsif ($b_common =~ qr[^([^!]+)[^!]*!\1]) {	# shared prefix between $b_sort and $req_sort?
				$l->debug("second stream is closely sorted ($1).");
				($a,$b)	= ($b,$a);
			}
		}
		@join_sorted_by	= ($a->sorted_by, $b->sorted_by);
	}
	
	my $stream	= $self->nested_loop_join( $a, $b, %args );
	$l->debug("JOINED stream is sorted by: " . join(',', @join_sorted_by));
	$stream->{sorted_by}	= \@join_sorted_by;
	return $stream;
}

=item C<< nested_loop_join ( $outer, $inner ) >>

Performs a natural, nested loop join of the two streams, returning a new stream
of joined results.

Note that the values from the C<< $inner >> iterator are fully materialized for
this join, and the results of the join are in the order of values from the
C<< $outer >> iterator. This suggests that:

* If sorting needs to be preserved, the C<< $outer >> iterator should be used to
determine the result ordering.

* If one iterator is much smaller than the other, it should likely be used as
the C<< $inner >> iterator since materialization will require less total memory.

=cut

sub nested_loop_join {
	my $self	= shift;
	my $astream	= shift;
	my $bstream	= shift;
#	my $bridge	= shift;
	my %args	= @_;
	
# 	Carp::confess unless ($astream->isa('RDF::Trine::Iterator::Bindings'));
# 	Carp::confess unless ($bstream->isa('RDF::Trine::Iterator::Bindings'));
	my $l		= Log::Log4perl->get_logger("rdf.trine.iterator.bindings");
	
	my @names	= RDF::Trine::_uniq( map { $_->binding_names() } ($astream, $bstream) );
	my $a		= $astream->project( @names );
	my $b		= $bstream->project( @names );
	
	
	my @data	= $b->get_all();
	no warnings 'uninitialized';
	
	my $inner_index;
	my $rowa;
	my $need_new_a	= 1;
	my $sub	= sub {
		OUTER: while (1) {
			if ($need_new_a) {
				$l->debug("### fetching new outer tuple");
				$rowa = $a->next;
				$inner_index	= 0;
				$need_new_a		= 0;
			}
			$l->debug("OUTER: " . Dumper($rowa));
			return unless ($rowa);
			LOOP: while ($inner_index <= $#data) {
				my $rowb	= $data[ $inner_index++ ];
				$l->debug("- INNER[ $inner_index ]: " . Dumper($rowb));
				$l->debug("[--JOIN--] " . join(' ', map { my $row = $_; '{' . join(', ', map { join('=', $_, ($row->{$_}) ? $row->{$_}->as_string : '(undef)') } (keys %$row)) . '}' } ($rowa, $rowb)));
				my %keysa	= map {$_=>1} (keys %$rowa);
				my @shared	= grep { $keysa{ $_ } } (keys %$rowb);
				foreach my $key (@shared) {
					my $val_a	= $rowa->{ $key };
					my $val_b	= $rowb->{ $key };
					my $defined	= 0;
					foreach my $n ($val_a, $val_b) {
						$defined++ if (defined($n));
					}
					if ($defined == 2) {
						my $equal	= $val_a->equal( $val_b );
						unless ($equal) {
							$l->debug("can't join because mismatch of $key (" . join(' <==> ', map {$_->as_string} ($val_a, $val_b)) . ")");
							next LOOP;
						}
					}
				}
				
				my $row	= { (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
				if ($l->is_debug) {
					$l->debug("JOINED:");
					foreach my $key (keys %$row) {
						$l->debug("$key\t=> " . $row->{ $key }->as_string);
					}
				}
				return $row;
			}
			$need_new_a	= 1;
		}
	};
	
	my $args	= $astream->_args;
	return $astream->_new( $sub, 'bindings', \@names, %$args );
}


=item C<< sorted_by >>

=cut

sub sorted_by {
	my $self	= shift;
	my $sorted	= $self->{sorted_by};
	return @$sorted;
}

=item C<< binding_value_by_name ( $name ) >>

Returns the binding of the named variable in the current result.

=cut

sub binding_value_by_name {
	my $self	= shift;
	my $name	= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	if (exists( $row->{ $name } )) {
		return $row->{ $name };
	} else {
# 		warn "No variable named '$name' is present in query results.\n";
		return;
	}
}

=item C<< binding_value ( $i ) >>

Returns the binding of the $i-th variable in the current result.

=cut

sub binding_value {
	my $self	= shift;
	my $val		= shift;
	my @names	= $self->binding_names;
	return $self->binding_value_by_name( $names[ $val ] );
}


=item C<binding_values>

Returns a list of the binding values from the current result.

=cut

sub binding_values {
	my $self	= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	return @{ $row }{ $self->binding_names };
}


=item C<binding_names>

Returns a list of the binding names.

=cut

sub binding_names {
	my $self	= shift;
	my $names	= $self->{_names};
	return @$names;
}

=item C<binding_name ( $i )>

Returns the name of the $i-th result column.

=cut

sub binding_name {
	my $self	= shift;
	my $val		= shift;
	my $names	= $self->{_names};
	return $names->[ $val ];
}


=item C<bindings_count>

Returns the number of variable bindings in the current result.

=cut

sub bindings_count {
	my $self	= shift;
	my $names	= $self->{_names};
	return scalar( @$names ) if (scalar(@$names));
	return 0;
}

=item C<is_bindings>

Returns true if the underlying result is a set of variable bindings.

=cut

sub is_bindings {
	my $self			= shift;
	return 1;
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
# 	my $bridge			= $self->bridge;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my @sorted	= $self->sorted_by;
	my $order	= scalar(@sorted) ? JSON::true : JSON::false;
	my $dist	= $self->_args->{distinct} ? JSON::true : JSON::false;
	
	my $data	= {
					head	=> { vars => \@variables },
					results	=> { ordered => $order, distinct => $dist, bindings => [] },
				};
	my @bindings;
	while (my $row = $self->next) {
		my %row	= map { format_node_json($row->{$_}, $_) } (keys %$row);
		push(@{ $data->{results}{bindings} }, \%row);
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	
	return to_json( $data );
}

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->print_xml( $fh, $max_result_size );
	close($fh);
	return $string;
}

=item C<as_string ( $max_size [, \$count] )>

Returns a string table serialization of the stream data.

=cut

sub as_string {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $rescount		= shift;
	my @names			= $self->binding_names;
	my $headers			= \@names;
	my @rows;
	my $count	= 0;
	while (my $row = $self->next) {
		push(@rows, [ map { blessed($_) ? RDF::Trine::Serializer::Turtle->node_as_concise_string($_) : '' } @{ $row }{ @names } ]);
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	if (ref($rescount)) {
		$$rescount	= scalar(@rows);
	}
	
	my @rule			= qw(- +);
	my @headers			= (\q"| ");
	push(@headers, map { $_ => \q" | " } @$headers);
	pop	@headers;
	push @headers => (\q" |");
	
	if ('ARRAY' eq ref $rows[0]) {
		if (@$headers == @{ $rows[0] }) {
			my $table = Text::Table->new(@headers);
			$table->rule(@rule);
			$table->body_rule(@rule);
			$table->load(@rows);
		
			return join('',
					$table->rule(@rule),
					$table->title,
					$table->rule(@rule),
					map({ $table->body($_) } 0 .. @rows),
					$table->rule(@rule)
				);
		} else {
			die("make_table() rows must be an AoA with rows being same size as headers");
		}
	} else {
		return '';
	}
}

=item C<< as_statements ( $pattern | @names ) >>

Returns a L<RDF::Trine::Iterator::Graph> with the statements of the stream.

If C<$pattern>, an RDF::Trine::Pattern object, is given as an argument, each of
its triples are instantiated with variable bindings from each row of the
iterator, and returned as RDF::Trine::Statement objects from a new
RDF::Trine::Iterator::Graph iterator.

If 3 variable C<@names> are supplied, their corresponding variable bindings
in each row of the iterator are used (in order) as the subject, predicate, and
object of new RDF::Trine::Statement objects and returned from a new
RDF::Trine::Iterator::Graph iterator.

=cut

sub as_statements {
	my $self	= shift;
	my @names	= @_;
	if (scalar(@names) == 1 and $names[0]->can('triples')) {
		my $pattern	= shift;
		my @triples	= $pattern->triples;
		my @queue;
		my $sub		= sub {
			while (1) {
				if (scalar(@queue)) {
					return shift(@queue);
				}
				my $row	= $self->next;
				return unless (defined $row);
				foreach my $t (@triples) {
					my $st	= $t->bind_variables($row);
					if ($st->rdf_compatible) {
						push(@queue, $st);
					}
				}
			}
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	} else {
		my $sub		= sub {
			my $row	= $self->next;
			return unless (defined $row);
			my @values	= @{ $row }{ @names };
			my $statement	= (scalar(@values) == 3 or not(defined($values[3])))
							? RDF::Trine::Statement->new( @values[ 0 .. 2 ] )
							: RDF::Trine::Statement::Quad->new( @values );
			return $statement;
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	}
}

=item C<< print_xml ( $fh, $max_size ) >>

Prints an XML serialization of the stream data to the filehandle $fh.

=cut

sub print_xml {
	my $self			= shift;
	my $fh				= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	print {$fh} <<"END";
<?xml version="1.0" encoding="utf-8"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
END
	
	my $t	= join("\n", map { qq(\t<variable name="$_"/>) } @variables);
	
	if ($t) {
		print {$fh} "${t}\n";
	}
	
	print {$fh} <<"END";
</head>
<results>
END
	
	my $count	= 0;
	while (my $row = $self->next) {
		my @row;
		print {$fh} "\t\t<result>\n";
		for (my $i = 0; $i < $width; $i++) {
			my $name	= $self->binding_name($i);
			my $value	= $row->{ $name };
			print {$fh} "\t\t\t" . $self->format_node_xml($value, $name) . "\n";
		}
		print {$fh} "\t\t</result>\n";
		
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	
	print {$fh} "</results>\n";
	print {$fh} "</sparql>\n";
}

=begin private

=item C<format_node_json ( $node, $name )>

Returns a string representation of C<$node> for use in a JSON serialization.

=end private

=cut

sub format_node_json {
# 	my $bridge	= shift;
# 	return unless ($bridge);
	
	my $node	= shift;
	my $name	= shift;
	my $node_label;
	
	if(!defined $node) {
		return;
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		$node_label	= $node->uri_value;
		return $name => { type => 'uri', value => $node_label };
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		$node_label	= $node->literal_value;
		return $name => { type => 'literal', value => $node_label };
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		$node_label	= $node->blank_identifier;
		return $name => { type => 'bnode', value => $node_label };
	} else {
		return;
	}
}

=item C<< construct_args >>

Returns the arguments necessary to pass to the stream constructor _new
to re-create this stream (assuming the same closure as the first
argument).

=cut

sub construct_args {
	my $self	= shift;
	my $type	= $self->type;
	my @names	= $self->binding_names;
	my $args	= $self->_args || {};
	return ($type, \@names, %{ $args });
}


1;

__END__

=back

=head1 DEPENDENCIES

L<JSON|JSON>

L<Scalar::Util|Scalar::Util>

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
