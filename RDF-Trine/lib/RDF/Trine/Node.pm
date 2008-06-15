# RDF::Trine::Node
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

our ($debug, $VERSION);
BEGIN {
	$debug		= 0;
	$VERSION	= '0.108';
}

use Scalar::Util qw(blessed);
use Unicode::String;

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
	return $self->sse;
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	return 0;
}

sub _unicode_escape {
	# based on Unicode::Escape, but without running the string through Encode:: first.
	my $self	= shift;
	my $str		= shift;
    my $us		= Unicode::String->new($str);
    my $rslt = '';
    while (my $uchar = $us->chop) {
        my $utf8 = $uchar->utf8;
        $rslt = (($utf8 =~ /[\x80-\xff]/) ? '\\u'.uc(unpack('H4', $uchar->utf16be)) : $utf8) . $rslt;
    }
    return $rslt;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
