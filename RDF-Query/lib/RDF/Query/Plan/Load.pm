# RDF::Query::Plan::Load
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Load - Executable query plan for LOAD operations.

=head1 VERSION

This document describes RDF::Query::Plan::Load version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Load;

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

=item C<< new ( $url, $graph ) >>

=cut

sub new {
	my $class	= shift;
	my $url		= shift;
	my $graph	= shift;
	my $self	= $class->SUPER::new( $url, $graph );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "LOAD plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.load");
	$l->trace( "executing RDF::Query::Plan::Load" );
	
	my %args	= ($self->namedgraph) ? (context => $self->namedgraph) : ();
	my $ok		= 0;
	try {
		RDF::Trine::Parser->parse_url_into_model( $self->url->uri_value, $context->model, %args );
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open LOAD";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.load");
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
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open LOAD";
	}
	
	delete $self->[0]{ok};
	$self->SUPER::close();
}

=item C<< url >>

Returns the URL to load data from.

=cut

sub url {
	my $self	= shift;
	return $self->[1];
}

=item C<< namedgraph >>

Returns the optional graph name to load the data with.

=cut

sub namedgraph {
	my $self	= shift;
	return $self->[2];
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
	return 'load';
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
	return ($self->url, $self->namedgraph);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	my $url		= $self->url->uri_value;
	$g->add_node( "$self", label => "Load" . $self->graph_labels );
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
