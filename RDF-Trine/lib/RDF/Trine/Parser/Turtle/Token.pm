package RDF::Trine::Parser::Turtle::Token;

use 5.014;
use MooseX::ArrayRef;

has type => ( is => 'ro', );
has start_line => ( is => 'ro', );
has start_column => ( is => 'ro', );
has line => ( is => 'ro', );
has column => ( is => 'ro', );
has args => ( is => 'ro', );

sub value {
	my $self	= shift;
	my $args	= $self->args;
	return $args->[0];
}

# This constructor relies on the list of attributes not changing order!
sub fast_constructor {
	my $class = shift;
	bless \@_, $class;
}

__PACKAGE__->meta->make_immutable;

1;
