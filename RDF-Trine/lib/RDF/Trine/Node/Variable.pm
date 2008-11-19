# RDF::Trine::Node::Variable
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Variable - RDF Node class for variables

=cut

package RDF::Trine::Node::Variable;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= 0.109;
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $name )>

Returns a new Variable structure.

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	return bless( [ $name ], $class );
}

=item C<< name >>

Returns the name of the variable.

=cut

sub name {
	my $self	= shift;
	return $self->[0];
}

=item C<< sse >>

Returns the SSE string for this variable.

=cut

sub sse {
	my $self	= shift;
	my $name	= $self->name;
	return qq(?${name});
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return '?' . $self->name;
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'VAR';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node'));
	return 0 unless ($self->type eq $node->type);
	return ($self->name eq $node->name);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
