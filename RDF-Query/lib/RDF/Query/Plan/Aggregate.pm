# RDF::Query::Plan::Aggregate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Aggregate - Executable query plan for Aggregates.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Aggregate;

use strict;
use warnings;
use base qw(RDF::Query::Plan);
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);

=item C<< new ( $pattern, \@group_by, [ $alias, $op, $attribute ], ... ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $groupby	= shift;
	my @ops		= @_;
	my $self	= $class->SUPER::new( $plan, $groupby, \@ops );
	$self->[0]{referenced_variables}	= [ uniq($plan->referenced_variables, map { $_->name } @$groupby) ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "AGGREGATE plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.aggregate");
	if ($plan->state == $self->OPEN) {
		my $query	= $context->query;
		my $bridge	= $context->model;
		
		my %seen;
		my %groups;
		my %aggregates;
		my @aggregators;
		my @groupby	= @{ $self->[2] };
		my @ops		= @{ $self->[3] };
		local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
		foreach my $data (@ops) {
			my ($alias, $op, $col)	= @$data;
			if ($op eq 'COUNT') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: COUNT");
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
					$l->debug("- aggregate op: COUNT-DISTINCT");
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
			} elsif ($op eq 'MAX') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: MAX");
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
					$l->debug("- aggregate op: MIN");
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
		
		while (my $row = $plan->next) {
			$l->debug("aggregate on $row");
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
			
			my $vars	= RDF::Query::VariableBindings->new( \%row );
			$l->debug("aggregate row: $vars");
			push(@rows, $vars);
		}
		
		$self->[0]{rows}	= \@rows;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in distinct";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open AGGREGATE";
	}
	return shift(@{ $self->[0]{rows} });
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open AGGREGATE";
	}
	delete $self->[0]{rows};
	$self->[1]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the aggregated data.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< groupby >>

Returns the grouping arguments that will be used to produce the aggregated data.

=cut

sub groupby {
	my $self	= shift;
	return @{ $self->[2] || [] };
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'aggregate';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P \E *\ssW);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my @group	= $self->groupby;
	my @ops		= @{ $self->[3] };
	return ($self->pattern, \@group, map { [@$_] } @ops);
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	return $self->pattern->distinct;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	my $sort	= $self->[2];
	return []; # XXX aggregates are actually sorted, so figure out what should go here...
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
