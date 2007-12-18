# RDF::Query::Algebra::Aggregate
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Aggregate - Algebra class for aggregate patterns

=cut

package RDF::Query::Algebra::Aggregate;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Iterator qw(smap);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, \@groupby, $alias => [$op => $col] )>

Returns a new Aggregate structure. Groups by the named bindings in C<< @groupby >>,
and returns new bindings for the named C<< $alias >> for the operation C<< $op >>
on column C<< $col >>.

C<< $op >> may be one of: COUNT, MIN, MAX.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $groupby	= shift;
	my @ops		= @_;
	return bless( [ $pattern, $groupby, \@ops ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my @ops		= @{ $self->[2] };
	return ($self->pattern, [ $self->groupby ], \@ops);
}

=item C<< pattern >>

Returns the aggregates pattern.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< groupby >>

Returns the aggregates GROUP BY binding names.

=cut

sub groupby {
	my $self	= shift;
	return @{ $self->[1] };
}

=item C<< ops >>

Returns a list of tuples as ARRAY refs containing C<< $alias, $op, $col >>.

=cut

sub ops {
	my $self	= shift;
	my @ops		= @{ $self->[2] };
	my @tuples;
	while (@ops) {
		my $alias	= shift(@ops);
		my $data	= shift(@ops);
		my ($op, $col)	= @$data;
		push(@tuples, [$alias, $op, $col]);
	}
	return @tuples;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my @ops_sse;
	my @ops		= $self->ops;
	foreach my $data (@ops) {
		my ($alias, $op, $col)	= @$data;
		push(@ops_sse, sprintf('(%s (%s %s))', $alias, $op, $col));
	}
	
	return sprintf(
		'(aggregate %s (%s) %s)',
		$self->pattern->sse( $context ),
		join(', ', $self->groupby),
		join(', ', @ops_sse)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	throw RDF::Query::Error -text => "Aggregates can't be serialized as SPARQL";
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'AGGREGATE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	return uniq( @aliases, $self->pattern->referenced_variables );
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	return @aliases;
}

=item C<< fixup ( $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	my $fixed	= $class->new(
					$self->pattern->fixup( $bridge, $base, $ns ),
					[ $self->groupby ],
					@{ $self->[2] }
				);
	return $fixed;
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	
	my %aggregates;
	my @aggregators;
	my %groups;
	my @groupby		= $self->groupby;
	foreach my $data ($self->ops) {
		my ($alias, $op, $col)	= @$data;
		if ($op eq 'COUNT') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= @{ $row }{ @groupby };
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				$aggregates{ $alias }{ $group }++;
			});
		} elsif ($op eq 'MAX') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= @{ $row }{ @groupby };
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				if (exists($aggregates{ $alias }{ $group })) {
					my $cmp	= $query->check_constraints( {}, [ '>', $row->{ $col }, $aggregates{ $alias }{ $group } ], bridge => $bridge );
					if ($cmp) {
						$aggregates{ $alias }{ $group }	= $row->{ $col };
					}
				} else {
					$aggregates{ $alias }{ $group }	= $row->{ $col };
				}
			});
		} elsif ($op eq 'MIN') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= @{ $row }{ @groupby };
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				if (exists($aggregates{ $alias }{ $group })) {
					my $cmp	= $query->check_constraints( {}, [ '<', $row->{ $col }, $aggregates{ $alias }{ $group } ], bridge => $bridge );
					warn "MIN: " . Dumper($cmp, $row->{ $col }, $aggregates{ $alias }{ $group });
					if ($cmp) {
						$aggregates{ $alias }{ $group }	= $row->{ $col };
					}
				} else {
					$aggregates{ $alias }{ $group }	= $row->{ $col };
				}
			});
		} else {
			throw RDF::Query::Error -text => "Unknown aggregate operator $op";
		}
	}
	
	
	
	$args{ orderby }	= [ map { [ 'ASC', RDF::Query::Node::Variable->new( $_ ) ] } @groupby ];
	my $stream		= $self->pattern->execute( $query, $bridge, $bound, $context, %args );
	while (my $row = $stream->next) {
		foreach my $agg (@aggregators) {
			$agg->( $row );
		}
	}
	
	my @rows;
	foreach my $group (keys %groups) {
		my $row	= $groups{ $group };
		my %row	= %$row;
		foreach my $agg (keys %aggregates) {
			my $value		= $aggregates{ $agg }{ $group };
			$row{ $agg }	= ($bridge->is_node($value)) ? $value : $bridge->new_literal( $value );
		}
		push(@rows, \%row);
	}
	
	my @cols	= (@groupby, keys %aggregates);
	return RDF::Iterator::Bindings->new(\@rows, \@cols);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
