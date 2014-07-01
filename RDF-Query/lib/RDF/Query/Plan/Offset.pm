# RDF::Query::Plan::Offset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Offset - Executable query plan for Offsets.

=head1 VERSION

This document describes RDF::Query::Plan::Offset version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Offset;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $plan, $offset ) >>

=cut

sub new {
	my $class	= shift;
	my $offset	= shift;
	my $plan	= shift;
	my $self	= $class->SUPER::new( $offset, $plan );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "OFFSET plan can't be executed while already open";
	}
	my $plan	= $self->[2];
	$self->[0]{exhausted}	= 0;
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
		for (my $i = 0; $i < $self->offset; $i++) {
			my $row	= $plan->next;
			if(not(defined($row))) {
				$self->[0]{exhausted}	= 1;
				last;
			}
		}
	} else {
		warn "could not execute plan in OFFSET";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	if ($self->[0]{exhausted}) {
		return undef;
	}
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open OFFSET";
	}
	my $plan	= $self->[2];
	my $row		= $plan->next;
	unless ($row) {
		$self->[0]{exhausted}	= 1;
		return undef;
	}
	if (my $d = $self->delegate) {
		$d->log_result( $self, $row );
	}
	return $row;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open OFFSET";
	}
	$self->[2]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be offset.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< offset >>

Returns the number of results that are discarded as offset.

=cut

sub offset {
	my $self	= shift;
	return $self->[1];
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
	return $self->pattern->ordered;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'offset';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(i P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->offset, $self->pattern);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	$g->add_node( "$self", label => "Offset ($self->[1])" . $self->graph_labels );
	$g->add_edge( "$self", $c );
	return "$self";
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
