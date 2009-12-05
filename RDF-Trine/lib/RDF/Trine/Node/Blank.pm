# RDF::Trine::Node::Blank
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Blank - RDF Node class for blank nodes

=head1 VERSION

This document describes RDF::Trine::Node::Blank version 0.112_02

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
	$VERSION	= '0.112_02';
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

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	my $self	= shift;
	my $id		= $self->blank_identifier;
	if ($id =~ m/[^A-Za-z0-9]/) {
		$id	=~ s/Z/ZZ/g;	# only alphanumerics are allowed in ntriples bnode ids, so we'll use 'Z' as the escape char
		$id	=~ s/([^A-Za-z0-9])/sprintf('Z%xz', ord($1))/ge;
	}
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

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
