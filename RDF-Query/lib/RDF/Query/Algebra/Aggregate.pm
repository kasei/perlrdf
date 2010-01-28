# RDF::Query::Algebra::Aggregate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Aggregate - Algebra class for aggregate patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Aggregate version 2.201_01, released 27 January 2010.

=cut

package RDF::Query::Algebra::Aggregate;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Scalar::Util qw(blessed);
use Data::Dumper;
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.201_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, \@groupby, $alias => [$op => $col] )>

Returns a new Aggregate structure. Groups by the named bindings in C<< @groupby >>,
and returns new bindings for the named C<< $alias >> for the operation C<< $op >>
on column C<< $col >>.

C<< $op >> may be one of: COUNT, MIN, MAX, SUM.

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
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	my @ops_sse;
	my @ops		= $self->ops;
	foreach my $data (@ops) {
		my ($alias, $op, $col)	= @$data;
		push(@ops_sse, sprintf('(alias "%s" (%s %s))', $alias, $op, ($col eq '*' ? '*' : $col->sse( $context, "${prefix}${indent}" ))));
	}
	
	my @group	= $self->groupby;
	my $group	= (@group) ? '(' . join(', ', @group) . ')' : '';
	return sprintf(
		"(aggregate\n${prefix}${indent}%s\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		join(', ', @ops_sse),
		$group,
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	throw RDF::Query::Error::SerializationError -text => "Aggregates can't be serialized as SPARQL";
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
	return RDF::Query::_uniq( @aliases, $self->pattern->referenced_variables );
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	throw Error; # XXX unimplemented
	return RDF::Query::_uniq( @aliases, $self->pattern->referenced_variables );
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	return @aliases;
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;

	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		my $fixed	= $class->new(
						$self->pattern->fixup( $query, $bridge, $base, $ns ),
						[ $self->groupby ],
						@{ $self->[2] }
					);
		return $fixed;
	}
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
	
	my %seen;
	my %groups;
	my %aggregates;
	my @aggregators;
	my @groupby		= $self->groupby;
	local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
	foreach my $data ($self->ops) {
		my ($alias, $op, $col)	= @$data;
		if ($op eq 'COUNT') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				
				unless ($groups{ $group }) {
					my %data;
					foreach my $i (0 .. $#groupby) {
						my $group	= $groupby[ $i ];
						my $key		= $group->can('name') ? $group->name : $group->as_sparql;
						my $value	= $group[ $i ];
						$data{ $key }	= $value;
					}
					$groups{ $group }	= \%data;
				}
				
				my $should_inc	= 0;
				if ($col eq '*') {
					$should_inc	= 1;
				} else {
					my $value	= $query->var_or_expr_value( $bridge, $row, $col );
					$should_inc	= (defined $value) ? 1 : 0;
				}
				
				$aggregates{ $alias }{ $group }	+= $should_inc;
			});
		} elsif ($op eq 'COUNT-DISTINCT') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				
				my @cols	= (blessed($col) ? $col->name : keys %$row);
				no warnings 'uninitialized';
				my $values	= join('<<<', @{ $row }{ @cols });
				if (exists($row->{ $col->name })) {
					$aggregates{ $alias }{ $group }++ unless ($seen{ $values }++);
				}
			});
		} elsif ($op eq 'SUM') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				if (exists($aggregates{ $alias }{ $group })) {
					$aggregates{ $alias }{ $group }	+= $row->{ $col->name };
				} else {
					$aggregates{ $alias }{ $group }	= $row->{ $col->name };
				}
			});
		} elsif ($op eq 'MAX') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				if (exists($aggregates{ $alias }{ $group })) {
					if ($row->{ $col->name } > $aggregates{ $alias }{ $group }) {
						$aggregates{ $alias }{ $group }	= $row->{ $col->name };
					}
				} else {
					$aggregates{ $alias }{ $group }	= $row->{ $col->name };
				}
			});
		} elsif ($op eq 'MIN') {
			push(@aggregators, sub {
				my $row		= shift;
				my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
				my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
				$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
				if (exists($aggregates{ $alias }{ $group })) {
					if ($row->{ $col->name } < $aggregates{ $alias }{ $group }) {
						$aggregates{ $alias }{ $group }	= $row->{ $col->name };
					}
				} else {
					$aggregates{ $alias }{ $group }	= $row->{ $col->name };
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
		my $row		= $groups{ $group };
		my %row		= %$row;
		foreach my $agg (keys %aggregates) {
			my $value		= $aggregates{ $agg }{ $group };
			$row{ $agg }	= ($bridge->is_node($value)) ? $value : $bridge->new_literal( $value, undef, 'http://www.w3.org/2001/XMLSchema#decimal' );
		}
		push(@rows, \%row);
	}
	
	my @cols	= (@groupby, keys %aggregates);
	return RDF::Trine::Iterator::Bindings->new(\@rows, \@cols);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
