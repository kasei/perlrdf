# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan;

use strict;
use warnings;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my @args	= @_;
	return bless( [ $class->READY, @args ], $class );
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($);

=item C<< next >>

=cut

sub next;

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	$self->state( CLOSED );
}

=item C<< state ( [ $state ] ) >>

Returns the current state of the plan (either READY, OPEN, or CLOSED).
If C<< $state >> is provided, updates the plan to a new state.

=cut

sub state {
	my $self	= shift;
	if (scalar(@_)) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

sub DESTROY {
	my $self	= shift;
	if ($self->state != CLOSED) {
		$self->close;
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
