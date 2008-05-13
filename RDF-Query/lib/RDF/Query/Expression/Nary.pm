# RDF::Query::Expression::Nary
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Nary - Class for n-ary expressions

=cut

package RDF::Query::Expression::Nary;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< sse >>

Returns the SSE string for this alegbra expression.

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

Returns the SPARQL string for this alegbra expression.

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
