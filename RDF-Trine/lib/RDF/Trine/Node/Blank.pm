# RDF::Trine::Node::Blank
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Blank - RDF Node class for blank nodes

=cut

package RDF::Trine::Node::Blank;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= 0.108;
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $name )>

Returns a new Blank structure.

=cut

my $COUNTER	= 0;
sub new {
	my $class	= shift;
	my $name	= shift;
	unless (defined($name)) {
		$name	= 'r' . time() . 'r' . $COUNTER++;
	}
	return bless( [ 'BLANK', $name ], $class );
}

=item C<< blank_identifier >>

Returns the identifier of the blank node.

=cut

sub blank_identifier {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this blank node.

=cut

sub sse {
	my $self	= shift;
	my $id		= $self->blank_identifier;
	return qq(_:${id});
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return	'(' . $self->blank_identifier . ')';
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'BLANK';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node'));
	return 0 unless ($self->type eq $node->type);
	return ($self->blank_identifier eq $node->blank_identifier);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
