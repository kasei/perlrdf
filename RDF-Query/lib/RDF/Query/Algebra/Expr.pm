# RDF::Query::Algebra::Expr
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Expr - Algebra class for Expr expressions

=cut

package RDF::Query::Algebra::Expr;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
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

=item C<new ( $op, @operands )>

Returns a new Expr structure.

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my @operands	= @_;
	return bless( [ 'EXPR', $op, @operands ] );
}

=item C<< op >>

Returns the operator of the expression.

=cut

sub op {
	my $self	= shift;
	return $self->[1];
}

=item C<< operands >>

Returns a list of the operands of the expression.

=cut

sub operands {
	my $self	= shift;
	return @{ $self }[ 2 .. $#{ $self } ];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	
	return sprintf(
		'(%s %s)',
		$self->op,
		join(' ', map { $self->sse } $self->operands),
	);
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'EXPR';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->name } grep { blessed($_) and $_->isa('RDF::Query::Node::Variable') } $self->operands);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
