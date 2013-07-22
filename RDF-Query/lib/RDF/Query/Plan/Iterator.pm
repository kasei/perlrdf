# RDF::Query::Plan::Iterator
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Iterator - Executable query plan for result-generating iterators.

=head1 VERSION

This document describes RDF::Query::Plan::Iterator version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Iterator;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed reftype);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $iter, \&execute_cb ) >>

=item C<< new ( \&create_iterator_cb ) >>

=cut

sub new {
	my $class	= shift;
	my $iter	= shift;
	my $cb		= shift;
	my $self	= $class->SUPER::new( $iter, $cb );
	$self->[0]{referenced_variables}	= [];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "ITERATOR plan can't be executed while already open";
	}
	
	if (ref($self->[2])) {
		$self->[2]->( $context );
	}
	
	# if we don't have an actual iterator, but only a promise of one, construct it now
	if (reftype($self->[1]) eq 'CODE' and not(blessed($self->[1]) and $self->[1]->isa('RDF::Trine::Iterator'))) {
		$self->[1]	= $self->[1]->( $context );
	}
	
	$self->state( $self->OPEN );
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open ITERATOR";
	}
	my $iter	= $self->[1];
	my $bindings	= $iter->next;
	if (my $d = $self->delegate) {
		$d->log_result( $self, $bindings );
	}
	return $bindings;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open ITERATOR";
	}
	my $iter	= $self->[1];
	$iter->close;
	$self->SUPER::close();
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
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'optimized-iterator';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw();
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
