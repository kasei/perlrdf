package RDF::Trine::Node::Blank;

use utf8;
use Moose;
use MooseX::Aliases;
use namespace::autoclean;

with 'RDF::Trine::Node::API::RDFNode';

alias $_ => 'value' for qw(blank_identifier);

my $COUNTER;
sub BUILDARGS {
	my $class = shift;
	
	if (!@_ or (@_==1 and not defined $_[0])) {
		return +{ value => 'r' . time() . 'r' . $COUNTER++ };
	}

	if (@_==1 and defined $_[0]) {
		return +{ value => $_[0] };
	}

	(@_==1 and ref $_[0] eq 'HASH')
		? $class->SUPER::BUILDARGS(@_)
		: $class->SUPER::BUILDARGS(+{@_})
}

{
	package RDF::Trine::Node::Blank::Exception::InvalidChar;
	use Moose;
	extends 'RDF::Trine::Exception';
	has identifier => (is => 'ro');
}

sub BUILD {
	my $self = shift;
	if ($self->value =~ m/[^A-Za-z0-9]/) {
		RDF::Trine::Node::Blank::Exception::InvalidChar->throw(
			message    => "Only alphanumerics are allowed in N-Triples bnode labels",
			identifier => $self->value,
		);
	}
}

sub type {
	'BLANK'
}

sub as_ntriples {
	sprintf('_:%s', shift->blank_identifier)
}

sub is_blank { 1 }

sub as_string {
	my $self	= shift;
	return	'(' . $self->blank_identifier . ')';
}

__PACKAGE__->meta->make_immutable;
1;


__END__

=head1 NAME

RDF::Trine::Node::Blank - a blank node

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new() >>

=item C<< new($identifier) >>

=item C<< new({ value => $identifier, %attrs }) >>

Constructs a blank node.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Attributes

=over

=item C<< value >>

The blank node identifier.

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< sse >>

Returns the node in SSE syntax.

=item C<< type >>

Returns the string 'BLANK'.

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns true.

=item C<< is_resource >>

Returns false.

=item C<< is_literal >>

Returns false.

=item C<< is_nil >>

Returns false.

=item C<< is_variable >>

Returns false.

=item C<< as_string >>

Returns a string representation of the node (currently identical to the SSE).

=item C<< equal($other) >>

Returns true if this node and is the same node as the other node.

=item C<< compare($other) >>

Like the C<< <=> >> operator, but sorts according to SPARQL ordering.

=item C<< as_ntriples >>

Returns an N-Triples representation of the node.

=back


