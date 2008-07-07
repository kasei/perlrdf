# RDF::Query::Expression::Unary
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Unary - Class for unary expressions

=cut

package RDF::Query::Expression::Unary;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
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
		map { $_->sse( $context ) } $self->operands,
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
	return sprintf("($op %s)", map { $_->as_sparql( $context, $indent ) } $self->operands);
}

=item C<< evaluate ( $query, $bridge, \%bound ) >>

Evaluates the expression using the supplied context (bound variables and bridge
object). Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift;
	my $bridge	= shift;
	my $bound	= shift;
	my $op		= $self->op;
	my ($data)	= $self->operands;
	my $l		= $data->isa('RDF::Query::Algebra')
				? $data->evaluate( $query, $bridge, $bound )
				: ($data->isa('RDF::Query::Node::Variable'))
					? $bound->{ $data->name }
					: $data;
	
	my $value;
	if ($op eq '+') {
		$value	= $l->numeric_value;
	} elsif ($op eq '-') {
		$value	= -1 * $l->numeric_value;
	} elsif ($op eq '!') {
		my $alg		= RDF::Query::Expression::Function->new( "sparql:ebv", $data );
		my $bool	= $alg->evaluate( $query, $bridge, $bound );
		if ($bool->literal_value eq 'true') {
			return RDF::Query::Node::Literal->new( 'false', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );
		} else {
			return RDF::Query::Node::Literal->new( 'true', undef, 'http://www.w3.org/2001/XMLSchema#boolean' );
		}
	} else {
		warn "unknown unary op: $op";
		die;
	}
	return RDF::Query::Node::Literal->new( $value, undef, $l->literal_datatype );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
