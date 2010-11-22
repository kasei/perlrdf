# RDF::Query::Plan::Iterator
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Iterator - Executable query plan for result-generating iterators.

=head1 VERSION

This document describes RDF::Query::Plan::Iterator version 2.904_01.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Iterator;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.904_01';
}

######################################################################

=item C<< new ( $iter, \&execute_cb ) >>

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
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "ITERATOR plan can't be executed while already open";
	}
	
	if (ref($self->[2])) {
		$self->[2]->( $context );
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
	return $iter->next;
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
