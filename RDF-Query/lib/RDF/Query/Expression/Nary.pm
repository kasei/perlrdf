# RDF::Query::Expression::Nary
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Nary - Class for n-ary expressions

=head1 VERSION

This document describes RDF::Query::Expression::Nary version 2.918.

=cut

package RDF::Query::Expression::Nary;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Expression> class.

=over 4

=cut

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(%s %s)',
		$self->op,
		join(' ', map { $_->sse( $context ) } $self->operands),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $op		= $self->op;
	my @args	= map { $_->as_sparql( $context, $indent ) } $self->operands;
	return join(" $op ", @args);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
