# RDF::Query::Plan::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Project - Executable query plan for Projects.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Project;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan, \@keys ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $keys	= shift;
	my $self	= $class->SUPER::new( $plan, $keys );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PROJECT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in PROJECT";
	}
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PROJECT";
	}
	my $plan	= $self->[1];
	my $row		= $plan->next;
	return undef unless ($row);
	
	my $keys	= $self->[2];
	return $row->project( @{ $keys } );
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PROJECT";
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
