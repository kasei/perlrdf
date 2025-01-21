# RDF::Query::Plan::Clear
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Clear - Executable query plan for CLEAR operations.

=head1 VERSION

This document describes RDF::Query::Plan::Clear version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Clear;

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
	$VERSION	= '2.918';
}

######################################################################

=item C<< new ( $graph ) >>

=cut

sub new {
	my $class	= shift;
	my $graph	= shift;
	my $self	= $class->SUPER::new( $graph );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "CLEAR plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.clear");
	$l->trace( "executing RDF::Query::Plan::Clear" );
	
	my %args	= ($self->namedgraph) ? (context => $self->namedgraph) : ();
	my $graph	= $self->namedgraph;
	unless ($graph) {
		$graph	= RDF::Trine::Node::Nil->new;
	}
# 	warn "clearing graph " . $graph->as_string;
	my $ok	= 0;
	try {
		if ($graph->is_nil) {
			$context->model->remove_statements( undef, undef, undef, $graph );
		} else {
			my $uri	= $graph->uri_value;
			if ($uri eq 'tag:gwilliams@cpan.org,2010-01-01:RT:ALL') {
				$context->model->remove_statements( undef, undef, undef, undef );
			} elsif ($uri eq 'tag:gwilliams@cpan.org,2010-01-01:RT:NAMED') {
				my $citer	= $context->model->get_graphs;
				while (my $graph = $citer->next) {
					$context->model->remove_statements( undef, undef, undef, $graph );
				}
			} else {
				$context->model->remove_statements( undef, undef, undef, $graph );
			}
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open CLEAR";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.clear");
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
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open CLEAR";
	}
	
	delete $self->[0]{ok};
	$self->SUPER::close();
}

=item C<< namedgraph >>

Returns the graph node which is to be cleared.

=cut

sub namedgraph {
	my $self	= shift;
	return $self->[1];
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
	return 'clear';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	my $g	= $self->namedgraph;
	if ($g->isa('RDF::Query::Node::Resource') and $g->uri_value =~ m'^tag:gwilliams@cpan[.]org,2010-01-01:RT:(NAMED|ALL)$') {
		return qw(w);
	} else {
		return qw(N);
	}
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $g	= $self->namedgraph;
	if ($g->isa('RDF::Query::Node::Resource') and $g->uri_value =~ m'^tag:gwilliams@cpan[.]org,2010-01-01:RT:(NAMED|ALL)$') {
		return $1;
	} else {
		return ($self->namedgraph);
	}
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	my $url		= $self->namedgraph->uri_value;
	$g->add_node( "$self", label => "Clear" . $self->graph_labels );
	$g->add_node( "${self}$url", label => $url );
	$g->add_edge( "$self" => "${self}$url", label => 'url' );
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
