# RDF::Trice::Node
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trice::Node - Base class for RDF Nodes

=head1 METHODS

=over 4

=cut

package RDF::Trice::Node;

use strict;
use warnings;
use Scalar::Util qw(blessed);

use RDF::Trice::Node::Blank;
use RDF::Trice::Node::Literal;
use RDF::Trice::Node::Resource;
use RDF::Trice::Node::Variable;

=item C<< is_node >>

Returns true if this object is a RDF node, false otherwise.

=cut

sub is_node {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trice::Node'));
}

=item C<< is_blank >>

Returns true if this RDF node is a blank node, false otherwise.

=cut

sub is_blank {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trice::Node::Blank'));
}

=item C<< is_resource >>

Returns true if this RDF node is a resource, false otherwise.

=cut

sub is_resource {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trice::Node::Resource'));
}

=item C<< is_literal >>

Returns true if this RDF node is a literal, false otherwise.

=cut

sub is_literal {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trice::Node::Literal'));
}

=item C<< is_variable >>

Returns true if this RDF node is a variable, false otherwise.

=cut

sub is_variable {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trice::Node::Variable'));
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
