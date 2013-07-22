# RDF::Query::Plan::Minus
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Minus - Executable query plan for minus operations.

=head1 VERSION

This document describes RDF::Query::Plan::Minus version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Minus;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::Error qw(:try);
use RDF::Query::ExecutionContext;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $lhs, $rhs ) >>

=cut

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	my $self	= $class->SUPER::new( $lhs, $rhs, @_ );
	
	my %vars;
	my @lhs_rv	= $lhs->referenced_variables;
	my @rhs_rv	= $rhs->referenced_variables;
	foreach my $v (@lhs_rv, @rhs_rv) {
		$vars{ $v }++;
	}
	$self->[0]{referenced_variables}	= [ keys %vars ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "Minus plan can't be executed while already open";
	}
	
	$self->[0]{start_time}	= [gettimeofday];
	my @inner;
	$self->rhs->execute( $context );
	while (my $row = $self->rhs->next) {
#		warn "*** loading inner row cache with: " . Dumper($row);
		push(@inner, $row);
	}
	$self->lhs->execute( $context );
	if ($self->lhs->state == $self->OPEN) {
		$self->[0]{inner}			= \@inner;
		$self->[0]{outer}			= $self->lhs;
		$self->[0]{inner_index}		= 0;
		$self->[0]{needs_new_outer}	= 1;
		$self->[0]{inner_count}		= 0;
		$self->[0]{count}			= 0;
		$self->[0]{logger}			= $context->logger;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
#	warn '########################################';
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open Minus";
	}
	my $outer	= $self->[0]{outer};
	my $inner	= $self->[0]{inner};
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.minus");
	while (1) {
		if ($self->[0]{needs_new_outer}) {
			$self->[0]{outer_row}	= $outer->next;
			if (ref($self->[0]{outer_row})) {
				$self->[0]{outer_row_vars}	= { map { $_ => 1 } $self->[0]{outer_row}->variables };
				$self->[0]{needs_new_outer}	= 0;
				$self->[0]{inner_index}		= 0;
				$self->[0]{inner_count}		= 0;
	#			warn "got new outer row: " . Dumper($self->[0]{outer_row});
			} else {
				# we've exhausted the outer iterator. we're now done.
	#			warn "exhausted";
				return undef;
			}
		}
		
		my $ok	= 1;
		while ($self->[0]{inner_index} < scalar(@$inner)) {
			my $inner_row	= $inner->[ $self->[0]{inner_index}++ ];
	#		warn "using inner row: " . Dumper($inner_row);
			my @shared	= grep { exists $self->[0]{outer_row_vars}{ $_ } } $inner_row->variables;
			if (scalar(@shared) == 0) {
				if ($l->is_trace) {
					$l->trace("no intersection of domains in minus: $inner_row ⋈ $self->[0]{outer_row}");
				}
			} elsif (my $joined = $inner_row->join( $self->[0]{outer_row} )) {
				if ($l->is_trace) {
					$l->trace("joined bindings in minus: $inner_row ⋈ $self->[0]{outer_row}");
				}
#				warn "-> joined\n";
				$self->[0]{inner_count}++;
				$self->[0]{count}++;
				$ok	= 0;
				last;
			} else {
				if ($l->is_trace) {
					$l->trace("failed to join bindings in minus: $inner_row ⋈ $self->[0]{outer_row}");
				}
			}
		}
		
		$self->[0]{needs_new_outer}	= 1;
		if ($ok) {
			my $bindings	= $self->[0]{outer_row};
			if (my $d = $self->delegate) {
				$d->log_result( $self, $bindings );
			}
			return $bindings;
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open Minus";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.minus");
	my $t0		= delete $self->[0]{start_time};
	my $count	= delete $self->[0]{count};
	if (my $log = delete $self->[0]{logger}) {
		$l->debug("logging minus execution statistics");
		my $elapsed = tv_interval ( $t0 );
		if (my $sparql = $self->logging_keys->{sparql}) {
			if ($l->is_trace) {
				$l->trace("- SPARQL: $sparql");
				$l->trace("- elapsed: $elapsed");
				$l->trace("- count: $count");
			}
			$log->push_key_value( 'execute_time-minus', $sparql, $elapsed );
			$log->push_key_value( 'cardinality-minus', $sparql, $count );
		}
		if (my $bf = $self->logging_keys->{bf}) {
			if ($l->is_trace) {
				$l->trace("- bf: $bf");
			}
			$log->push_key_value( 'cardinality-bf-minus', $bf, $count );
		}
	}
	delete $self->[0]{inner};
	delete $self->[0]{outer};
	delete $self->[0]{inner_index};
	delete $self->[0]{needs_new_outer};
	delete $self->[0]{inner_count};
	$self->lhs->close();
	$self->rhs->close();
	$self->SUPER::close();
}

=item C<< lhs >>

Returns the left-hand-side plan to the join.

=cut

sub lhs {
	my $self	= shift;
	return $self->[1];
}

=item C<< rhs >>

Returns the right-hand-side plan to the join.

=cut

sub rhs {
	my $self	= shift;
	return $self->[2];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return 0;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	my $self	= shift;
	return 'minus';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $expr	= $self->[2];
	return ($self->lhs, $self->rhs);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my ($l, $r)	= map { $_->graph( $g ) } ($self->lhs, $self->rhs);
	$g->add_node( "$self", label => "Minus" . $self->graph_labels );
	$g->add_edge( "$self", $l );
	$g->add_edge( "$self", $r );
	return "$self";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
