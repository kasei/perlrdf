# RDF::Query::Plan::NamedGraph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::NamedGraph - Executable query plan for named graphs.

=head1 VERSION

This document describes RDF::Query::Plan::NamedGraph version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::NamedGraph;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################


=item C<< new ( $graph, $plan ) >>

=cut

sub new {
	my $class	= shift;
	my $graph	= shift;
	my $plan	= shift;
	my $self	= $class->SUPER::new( $graph, $plan );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.namedgraph");
	$l->trace('constructing named graph plan...');
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "NamedGraph plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.namedgraph");
	$l->trace('executing named graph plan');
	my $model	= $context->model;
	my $graphs	= $model->get_graphs;
	$self->[0]{graphs}	= $graphs;
	$self->[0]{bound}	= $context->bound || {};
	$self->[0]{context}	= $context;
	
	if (my $g = $self->[0]{graphs}->next) {
		my %bound	= %{ $self->[0]{bound} };
		$bound{ $self->graph->name }	= $g;
		my $ctx		= $context->copy( bound => \%bound );
		my $plan	= $self->pattern;
		$l->trace("Executing named graph pattern with graph " . $g->as_string . ": " . $plan->sse);
		$plan->execute( $ctx );
		$self->[0]{current_graph}	= $g;
	}
	
	$self->state( $self->OPEN );
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open NAMED GRAPH";
	}
	my $context	= $self->[0]{context};
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.namedgraph");
	while (1) {
		unless ($self->[0]{current_graph}) {
			return;
		}
		my $row	= $self->pattern->next;
		if ($row) {
			my $g	= $self->[0]{current_graph};
			if (my $rg = $row->{ $self->graph->name }) {
				unless ($rg->equal( $g )) {
					next;
				}
			}
			$row->{ $self->graph->name }	= $g;
			if (my $d = $self->delegate) {
				$d->log_result( $self, $row );
			}
			return $row;
		} else {
			my $g		= $self->[0]{graphs}->next;
			unless (blessed($g)) {
				return;
			}
			my %bound	= %{ $self->[0]{bound} };
			$bound{ $self->graph->name }	= $g;
			my $ctx		= $self->[0]{context}->copy( bound => \%bound );
			my $plan	= $self->pattern;
			if ($plan->state == $plan->OPEN) {
				$plan->close();
			}
			$l->trace("Executing named graph pattern with graph " . $g->as_string);
			$plan->execute( $ctx );
			$self->[0]{current_graph}	= $g;
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open NAMED GRAPH";
	}
	delete $self->[0]{current_graph};
	my $plan	= $self->pattern;
	if ($plan->state == $plan->OPEN) {
		$plan->close();
	}
	$self->SUPER::close();
}

=item C<< graph >>

Returns the graph variable.

=cut

sub graph {
	my $self	= shift;
	return $self->[1];
}

=item C<< pattern >>

Returns the query plan that will be used with each named graph in the model.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
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
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'named-graph';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(N P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->graph, $self->pattern);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
