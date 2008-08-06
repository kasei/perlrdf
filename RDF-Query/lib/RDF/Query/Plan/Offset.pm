# RDF::Query::Plan::Offset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Offset - Executable query plan for Offsets.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Offset;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan, $offset ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $offset	= shift;
	my $self	= $class->SUPER::new( $plan, $offset );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "OFFSET plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
		for (my $i = 0; $i < $self->[2]; $i++) {
			$plan->next;
		}
	} else {
		warn "could not execute plan in OFFSET";
	}
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open OFFSET";
	}
	my $plan	= $self->[1];
	my $row		= $plan->next;
	return undef unless ($row);
	return $row;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open OFFSET";
	}
	$self->[1]->close();
	$self->SUPER::close();
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
