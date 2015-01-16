# RDF::Trine::Node::Nil
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Nil - RDF Node class for the nil node

=head1 VERSION

This document describes RDF::Trine::Node::Nil version 1.012

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
	$VERSION	= '1.012';
}

######################################################################

use overload	'""'	=> sub { $_[0]->sse },
			;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Node> class.

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

=item C<< as_ntriples >>

Returns the N-Triples serialization of the nil node's IRI
<tag:gwilliams@cpan.org,2010-01-01:RT:NIL>.

=cut

sub as_ntriples {
	my $self	= shift;
	return sprintf('<%s>', &RDF::Trine::NIL_GRAPH());
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'NIL';
}

=item C<< value >>

Returns the empty string.

=cut

sub value {
	my $self	= shift;
	return '';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node));
	if ($self->isa('RDF::Trine::Node::Nil') and $node->isa('RDF::Trine::Node::Nil')) {
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

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
