package RDF::Trine::Node::API::Canonicalize;

use utf8;
use Moose::Role;
use MooseX::Types::Moose qw(Str);

requires qw(
	value
	datatype
	_build_is_valid_lexical_form
	_build_canonical_lexical_form
);

sub does_canonicalization   { 1 }
sub does_lexical_validation { 1 }

has is_valid_lexical_form => (
	is        => 'ro',
	isa       => Str,
	lazy      => 1,
	builder   => '_build_is_valid_lexical_form',
	init_arg  => undef,
);
	
has canonical_lexical_form => (
	is        => 'ro',
	isa       => Str,
	lazy      => 1,
	builder   => '_build_canonical_lexical_form',
	init_arg  => undef,
);

sub is_canonical_lexical_form
{
	my $self = shift;
	warn '----> ' . $self->canonical_lexical_form . "\n";
	eval { $self->value eq $self->canonical_lexical_form } or 0;
}

sub canonicalize
{
	my $self = shift;
	RDF::Trine::Node::Literal->new({
		value    => $self->canonical_lexical_form,
		datatype => $self->datatype,
	});
}	

1;

__END__

=head1 NAME

RDF::Trine::Node::API::Canonicalize - role for literals with datatypes that can be canonicalized

=head1 DESCRIPTION

=head2 Requires

This role requires consuming classes to implement the following methods:

=over

=item C<< value >>

=item C<< datatype >>

=item C<< _build_is_valid_lexical_form >>

=item C<< _build_canonical_lexical_form >>

=back

=head2 Methods

This role provides the following methods:

=over

=item C<< is_valid_lexical_form >>

Returns true if the literal value is lexically valid for its datatype.

=item C<< is_canonical_lexical_form >>

Returns true if the literal value is canonical for its datatype.

=item C<< canonical_lexical_form >>

Returns the canonical lexical form for the literal value, as a string.

For example, the decimal number C<< 1.10 >> would be canonicalized as C<< 1.1 >>.

=item C<< canonicalize >>

Like C<< canonical_lexical_form >> but returns a new
L<RDF::Trine::Node::Literal> object.

=back

