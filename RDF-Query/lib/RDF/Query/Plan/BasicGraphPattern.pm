# RDF::Query::Plan::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::BasicGraphPattern - Executable query plan for BasicGraphPatterns.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::BasicGraphPattern;

use strict;
use warnings;

=item C<< new ( $bgp ) >>

=cut

sub new {
	my $class	= shift;
	my $bgp		= shift;
	return $class->SUPER::new( $bgp );
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	unless ($self->state == READY) {
		throw RDF::Query::Error::ExecutionError -text => "BGP plan cann't be executed twice";
	}
	
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open BGP";
	}
	
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open BGP";
	}
	
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
