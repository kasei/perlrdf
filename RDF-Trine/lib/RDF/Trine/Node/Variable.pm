package RDF::Trine::Node::Variable;

use utf8;
use Moose;
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

with 'RDF::Trine::Node::API';

has name => (
	is   => 'ro',
	isa  => Str,
);

sub BUILDARGS {
	if (@_ == 2 and not ref $_[1]) {
		return +{ name => $_[1] };
	}
	return shift->SUPER::BUILDARGS(@_);
}

sub type {
	'VAR'
}

sub sse {
	sprintf '?%s', shift->name;
}

{
	package RDF::Trine::Node::Variable::Exception::NTriples;
	use Moose;
	extends 'RDF::Trine::Exception';
	has variable => (is => 'ro');
}

sub as_ntriples {
	RDF::Trine::Node::Variable::Exception::NTriples->throw(
		message  => "Variable nodes aren't allowed in NTriples",
		variable => $_[0],
	);
}

sub _compare { $_[0]->name cmp $_[1]->name }

sub is_variable { 1 }

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

RDF::Trine::Node::Variable - a variable in a pattern

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new($name) >>

=item C<< new(name => $name) >>

Constructs a variable with the given name.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Attributes

=over

=item C<< name >>

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< sse >>

Returns the node in SSE syntax.

=item C<< type >>

Returns the string 'VAR'.

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns false.

=item C<< is_resource >>

Returns false.

=item C<< is_literal >>

Returns false.

=item C<< is_nil >>

Returns false.

=item C<< is_variable >>

Returns true.

=item C<< as_string >>

Returns a string representation of the node (currently identical to the SSE).

=item C<< equal($other) >>

Returns true if this node and is the same node as the other node.

=item C<< compare($other) >>

Like the C<< <=> >> operator, but sorts according to SPARQL ordering.

=item C<< as_ntriples >>

Always throws an exception.

=back

