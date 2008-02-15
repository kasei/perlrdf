# RDF::Trine::Node
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node - Base class for RDF Nodes

=head1 METHODS

=over 4

=cut

package RDF::Trine::Node;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);

use RDF::Trine::Node::Blank;
use RDF::Trine::Node::Literal;
use RDF::Trine::Node::Resource;
use RDF::Trine::Node::Variable;

=item C<< is_node >>

Returns true if this object is a RDF node, false otherwise.

=cut

sub is_node {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node'));
}

=item C<< is_blank >>

Returns true if this RDF node is a blank node, false otherwise.

=cut

sub is_blank {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Blank'));
}

=item C<< is_resource >>

Returns true if this RDF node is a resource, false otherwise.

=cut

sub is_resource {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Resource'));
}

=item C<< is_literal >>

Returns true if this RDF node is a literal, false otherwise.

=cut

sub is_literal {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Literal'));
}

=item C<< is_variable >>

Returns true if this RDF node is a variable, false otherwise.

=cut

sub is_variable {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Variable'));
}

=item C<< as_string >>

Returns the node in a string form.

=cut

sub as_string {
	my $self	= shift;
	return $self->as_sparql;
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	return 0;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
