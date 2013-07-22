# RDF::Query::Plan::Move
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Move - Executable query plan for MOVE operations.

=head1 VERSION

This document describes RDF::Query::Plan::Move version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Move;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::Error qw(:try);
use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $from, $to, $silent ) >>

=cut

sub new {
	my $class	= shift;
	my $from	= shift;
	my $to		= shift;
	my $silent	= shift;
	my $self	= $class->SUPER::new( $from, $to, $silent );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "MOVE plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.move");
	$l->trace( "executing RDF::Query::Plan::Move" );
	
	my $from	= $self->from;
	my $to		= $self->to;
# 	warn "Moving graph " . $from->as_string;
	my $ok	= 0;
	try {
		if ($from->equal( $to )) {
			# no-op
		} else {
			my $model	= $context->model;
			$model->begin_bulk_ops();
			$model->remove_statements( undef, undef, undef, $to );
			my $iter	= $model->get_statements( undef, undef, undef, $from );
			while (my $st = $iter->next) {
				$model->add_statement( $st, $to );
			}
			$context->model->remove_statements( undef, undef, undef, $from );
			$model->end_bulk_ops();
		}
		$ok		= 1;
	} catch RDF::Trine::Error with {};
	$self->[0]{ok}	= $ok;
	$self->state( $self->OPEN );
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open MOVE";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.move");
	$self->close();
	if (my $d = $self->delegate) {
		$d->log_result( $self, $self->[0]{ok} );
	}
	return $self->[0]{ok};
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open MOVE";
	}
	
	delete $self->[0]{ok};
	$self->SUPER::close();
}

=item C<< from >>

Returns the graph node which is to be copied.

=cut

sub from {
	my $self	= shift;
	return $self->[1];
}

=item C<< to >>

Returns the graph node to which data is copied.

=cut

sub to {
	my $self	= shift;
	return $self->[2];
}

=item C<< silent >>

Returns the silent flag.

=cut

sub silent {
	my $self	= shift;
	return $self->[3];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 1;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'move';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->from, $self->to);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	my $furl	= $self->from->uri_value;
	my $turl	= $self->to->uri_value;
	$g->add_node( "$self", label => "Move" . $self->graph_labels );
	$g->add_node( "${self}$furl", label => $furl );
	$g->add_node( "${self}$turl", label => $turl );
	$g->add_edge( "$self" => "${self}$furl", label => 'from' );
	$g->add_edge( "$self" => "${self}$turl", label => 'to' );
	return "$self";
}

=item C<< is_update >>

Returns true if the plan represents an update operation.

=cut

sub is_update {
	return 1;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
