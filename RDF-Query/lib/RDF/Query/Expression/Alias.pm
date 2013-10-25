# RDF::Query::Expression::Alias
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Alias - Class for aliasing expressions with variable names

=head1 VERSION

This document describes RDF::Query::Expression::Alias version 2.910.

=cut

package RDF::Query::Expression::Alias;

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
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Expression> class.

=over 4

=cut

=item C<< name >>

Returns the variable name of the aliased expression.

=cut

sub name {
	my $self	= shift;
	return $self->alias->name;
}

=item C<< alias >>

Returns the variable object of the aliased expression.

=cut

sub alias {
	my $self	= shift;
	my ($alias)	= $self->operands;
	return $alias;
}

=item C<< expression >>

Returns the expression object of the aliased expression.

=cut

sub expression {
	my $self	= shift;
	return ($self->operands)[1];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(alias ?%s %s)',
		$self->name,
		$self->expression->sse( $context ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $alias	= $self->alias;
	my $expr	= $self->expression;
	return sprintf("(%s AS %s)", $expr->as_sparql, $alias->as_sparql);
}

=item C<< evaluate ( $query, \%bound, $context ) >>

Evaluates the expression using the supplied bound variables.
Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift;
	my $bound	= shift;
	my $ctx		= shift;
	my $expr	= $self->expression;
	my $value	= $query->var_or_expr_value( $bound, $expr, $ctx );
	return $value;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
