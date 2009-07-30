# RDF::Query::Node::Variable
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Variable - RDF Node class for variables

=head1 VERSION

This document describes RDF::Query::Node::Variable version 2.200_01, released XX July 2009.

=cut

package RDF::Query::Node::Variable;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Variable);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
