# RDF::Trine::Node::Nil
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Nil - RDF Node class for the nil node

=head1 VERSION

This document describes RDF::Trine::Node::Nil version 0.115

=cut

package RDF::Trine::Node::Nil;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use Data::Dumper;
use Scalar::Util qw(blessed refaddr);
use Carp qw(carp croak confess);

######################################################################

my $NIL_NODE;
our ($VERSION);
BEGIN {
	$VERSION	= '0.115';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new () >>

Returns the nil-valued node.

=cut

sub new {
	my $class	= shift;
	if (blessed($NIL_NODE)) {
		return $NIL_NODE;
	} else {
		$NIL_NODE	= bless({}, $class);
		return $NIL_NODE;
	}
}

=item C<< is_nil >>

Returns true if this object is the nil-valued node.

=cut

sub is_nil {
	my $self	= shift;
	return (refaddr($self) == refaddr($NIL_NODE));
}

=item C<< sse >>

Returns the SSE string for this nil node.

=cut

sub sse {
	my $self	= shift;
	return '(nil)';
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'NIL';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node));
	if ($self->is_nil and $node->is_nil) {
		return 1;
	} else {
		return 0;
	}
}

# called to compare two nodes of the same type
sub _compare {
	return 0;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
