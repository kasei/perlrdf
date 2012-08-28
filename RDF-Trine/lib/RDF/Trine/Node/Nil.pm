package RDF::Trine::Node::Nil;

use utf8;
use Scalar::Util qw(refaddr);

use Moose;
use MooseX::Singleton;

with 'RDF::Trine::Node::API';

sub is_nil { 1 }
sub sse { '(nil)' }
sub value { '' }
sub as_ntriples {
	my $self = shift;
	return sprintf('<%s>', RDF::Trine::NIL_GRAPH());
}
sub type { 'NIL' }
sub equal { refaddr(shift)==refaddr(shift) }
sub _compare { 0 }

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

RDF::Trine::Node::Nil - a node that is not a node

=head1 DESCRIPTION

This node crops up in places like the "graph" slot of non-quad statements.
It is a singleton.

=head2 Constructor

=over

=item C<< new >>

Takes no parameters.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< sse >>

Returns the node in SSE syntax.

=item C<< type >>

Returns the string 'NIL'.

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns false.

=item C<< is_resource >>

Returns false.

=item C<< is_literal >>

Returns false.

=item C<< is_nil >>

Returns true.

=item C<< is_variable >>

Returns false.

=item C<< as_string >>

Returns a string representation of the node (currently identical to the SSE).

=item C<< equal($other) >>

Returns true if this node and is the same node as the other node.

=item C<< compare($other) >>

Like the C<< <=> >> operator, but sorts according to SPARQL ordering.

=item C<< value >>

Returns the empty string.

=item C<< as_ntriples >>

Returns an N-Triples IRI representing the concept of nil.

=back

