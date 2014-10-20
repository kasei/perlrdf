package RDF::Trine::Parser::Turtle::Token;

use 5.010;
use strict;
use warnings;
use MooseX::ArrayRef;

has type => ( is => 'ro', );
has start_line => ( is => 'ro', );
has start_column => ( is => 'ro', );
has line => ( is => 'ro', );
has column => ( is => 'ro', );
has args => ( is => 'ro', );

=begin private

=item C<< value >>

Returns the token value.

=cut

sub value {
	my $self	= shift;
	my $args	= $self->args;
	return $args->[0];
}

=item C<< fast_constructor ( $type, $line, $col, \@args ) >>

Returns a new token object.

=cut

# This constructor relies on the list of attributes not changing order!
sub fast_constructor {
	my $class = shift;
	bless \@_, $class;
}

__PACKAGE__->meta->make_immutable;

1;

=end private

=cut
