# RDF::Query::Plan::Aggregate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Aggregate - Executable query plan for Aggregates.

=head1 VERSION

This document describes RDF::Query::Plan::Aggregate version 2.200, released 6 August 2009.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Aggregate;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use RDF::Query::Error qw(:try);
use Scalar::Util qw(blessed);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200';
}

######################################################################

=item C<< new ( $pattern, \@group_by, [ $alias, $op, $attribute ], ... ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $groupby	= shift;
	my @ops		= @_;
	my $self	= $class->SUPER::new( $plan, $groupby, \@ops );
	$self->[0]{referenced_variables}	= [ RDF::Query::_uniq($plan->referenced_variables, map { $_->name } @$groupby) ];
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
					
					$aggregates{ $alias }{ $group }[0]	= $op;
					$aggregates{ $alias }{ $group }[1]	+= $should_inc;
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
					$aggregates{ $alias }{ $group }[0]	= $op;
					if (exists($row->{ $col->name })) {
						$aggregates{ $alias }{ $group }[1]++ unless ($seen{ $values }++);
					}
				});
			} elsif ($op eq 'SUM') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: SUM");
					my $row		= shift;
					my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
					my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
					$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
					my $value	= $row->{ $col->name };
					my $type	= _node_type( $value );
					$aggregates{ $alias }{ $group }[0]	= $op;
					
					my $strict	= 1;
					if (scalar( @{ $aggregates{ $alias }{ $group } } ) > 1) {
						if ($type ne $aggregates{ $alias }{ $group }[2]) {
							if ($context->strict_errors) {
								throw RDF::Query::Error::ComparisonError -text => "Cannot compute SUM aggregate over nodes of multiple types";
							} else {
								$strict	= 0;
							}
						}
						
						$aggregates{ $alias }{ $group }[1]	+= $value;
						$aggregates{ $alias }{ $group }[2]	= $type;
					} else {
						$aggregates{ $alias }{ $group }[1]	= $value;
						$aggregates{ $alias }{ $group }[2]	= $type;
					}
				});
			} elsif ($op eq 'MAX') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: MAX");
					my $row		= shift;
					my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
					my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
					$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
					my $value	= $row->{ $col->name };
					my $type	= _node_type( $value );
					$aggregates{ $alias }{ $group }[0]	= $op;
					
					my $strict	= 1;
					if (scalar( @{ $aggregates{ $alias }{ $group } } ) > 1) {
						if ($type ne $aggregates{ $alias }{ $group }[2]) {
							if ($context->strict_errors) {
								throw RDF::Query::Error::ComparisonError -text => "Cannot compute MAX aggregate over nodes of multiple types";
							} else {
								$strict	= 0;
							}
						}
						
						if ($strict) {
							if ($value > $aggregates{ $alias }{ $group }[1]) {
								$aggregates{ $alias }{ $group }[1]	= $value;
								$aggregates{ $alias }{ $group }[2]	= $type;
							}
						} else {
							if ("$value" gt "$aggregates{ $alias }{ $group }[1]") {
								$aggregates{ $alias }{ $group }[1]	= $value;
								$aggregates{ $alias }{ $group }[2]	= $type;
							}
						}
					} else {
						$aggregates{ $alias }{ $group }[1]	= $value;
						$aggregates{ $alias }{ $group }[2]	= $type;
					}
				});
			} elsif ($op eq 'MIN') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: MIN");
					my $row		= shift;
					my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
					my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
					$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
					my $value	= $row->{ $col->name };
					my $type	= _node_type( $value );
					$aggregates{ $alias }{ $group }[0]	= $op;
					
					my $strict	= 1;
					if (scalar( @{ $aggregates{ $alias }{ $group } } ) > 1) {
						if ($type ne $aggregates{ $alias }{ $group }[2]) {
							if ($context->strict_errors) {
								throw RDF::Query::Error::ComparisonError -text => "Cannot compute MIN aggregate over nodes of multiple types";
							} else {
								$strict	= 0;
							}
						}
						
						if ($strict) {
							if ($value < $aggregates{ $alias }{ $group }[1]) {
								$aggregates{ $alias }{ $group }[1]	= $value;
								$aggregates{ $alias }{ $group }[2]	= $type;
							}
						} else {
							if ("$value" lt "$aggregates{ $alias }{ $group }[1]") {
								$aggregates{ $alias }{ $group }[1]	= $value;
								$aggregates{ $alias }{ $group }[2]	= $type;
							}
						}
					} else {
						$aggregates{ $alias }{ $group }[1]	= $value;
						$aggregates{ $alias }{ $group }[2]	= $type;
					}
				});
			} elsif ($op eq 'AVG') {
				push(@aggregators, sub {
					$l->debug("- aggregate op: AVG");
					my $row		= shift;
					my @group	= map { $query->var_or_expr_value( $bridge, $row, $_ ) } @groupby;
					my $group	= join('<<<', map { $bridge->as_string( $_ ) } @group);
					$groups{ $group }	||= { map { $_ => $row->{ $_ } } @groupby };
					my $value	= $row->{ $col->name };
					my $type	= _node_type( $value );
					$aggregates{ $alias }{ $group }[0]	= $op;
					
					if (my $cmp = $aggregates{ $alias }{ $group }[3]) {
						if ($type ne $cmp) {
							if ($context->strict_errors) {
								throw RDF::Query::Error::ComparisonError -text => "Cannot compute AVG aggregate over nodes of multiple types";
							}
						}
					}
					
					if (blessed($value) and $value->isa('RDF::Query::Node::Literal') and $value->is_numeric_type) {
						$aggregates{ $alias }{ $group }[1]++;
						$aggregates{ $alias }{ $group }[2]	+= $value->numeric_value;
						$aggregates{ $alias }{ $group }[3]	= $type;
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
				my $op			= $aggregates{ $agg }{ $group }[0];
				if ($op eq 'AVG') {
					my $value	= ($aggregates{ $agg }{ $group }[2] / $aggregates{ $agg }{ $group }[1]);
					$row{ $agg }	= ($bridge->is_node($value)) ? $value : $bridge->new_literal( $value, undef, 'http://www.w3.org/2001/XMLSchema#float' );
				} elsif ($op =~ /COUNT/) {
					my $value	= $aggregates{ $agg }{ $group }[1];
					$row{ $agg }	= ($bridge->is_node($value)) ? $value : $bridge->new_literal( $value, undef, 'http://www.w3.org/2001/XMLSchema#integer' );
				} else {
					my $value	= $aggregates{ $agg }{ $group }[1];
					$row{ $agg }	= ($bridge->is_node($value)) ? $value : $bridge->new_literal( $value, undef, $aggregates{ $agg }{ $group }[1] );
				}
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

sub _node_type {
	my $node	= shift;
	if (blessed($node)) {
		if ($node->isa('RDF::Query::Node::Literal')) {
			if (my $type = $node->literal_datatype) {
				return $type;
			} else {
				return 'literal';
			}
		} elsif ($node->isa('RDF::Query::Node::Resource')) {
			return 'resource';
		} elsif ($node->isa('RDF::Query::Node::Blank')) {
			return 'blank';
		} else {
			return '';
		}
	} else {
		return '';
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
