# RDF::Trice::Node::Blank
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trice::Node::Blank - RDF Node class for blank nodes

=cut

package RDF::Trice::Node::Blank;

use strict;
use warnings;
use base qw(RDF::Trice::Node);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
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

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
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
	return 0 unless (blessed($node) and $node->isa('RDF::Trice::Node'));
	return 0 unless ($self->type eq $node->type);
	return ($self->blank_identifier eq $node->blank_identifier);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
