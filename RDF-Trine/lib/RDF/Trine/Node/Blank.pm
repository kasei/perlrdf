# RDF::Trine::Node::Blank
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Blank - RDF Node class for blank nodes

=head1 VERSION

This document describes RDF::Trine::Node::Blank version 0.134_02

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

our ($VERSION);
BEGIN {
	$VERSION	= '0.134_02';
}

######################################################################

use overload	'""'	=> sub { $_[0]->sse },
			;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Node> class.

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
	if ($name =~ m/[^A-Za-z0-9]/) {
		throw RDF::Trine::Error::SerializationError -text => "Only alphanumerics are allowed in N-Triples bnode labels";
	}
	return $class->_new( $name );
}

sub _new {
	my $class	= shift;
	my $name	= shift;
	return bless( [ 'BLANK', $name ], $class );
}

=item C<< blank_identifier >>

Returns the identifier of the blank node.

=cut

sub blank_identifier {
	my $self	= shift;
	return $self->[1];
}

=item C<< value >>

Returns the blank identifier.

=cut

sub value {
	my $self	= shift;
	return $self->blank_identifier;
}

=item C<< sse >>

Returns the SSE string for this blank node.

=cut

sub sse {
	my $self	= shift;
	my $id		= $self->blank_identifier;
	return qq(_:${id});
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
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
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node::Blank'));
	return ($self->blank_identifier eq $node->blank_identifier);
}

# called to compare two nodes of the same type
sub _compare {
	my $a	= shift;
	my $b	= shift;
	return ($a->blank_identifier cmp $b->blank_identifier);
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
