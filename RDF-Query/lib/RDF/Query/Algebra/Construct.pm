# RDF::Query::Algebra::Construct
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Construct - Algebra class for construct query results

=head1 VERSION

This document describes RDF::Query::Algebra::Construct version 2.202, released 30 January 2010.

=cut

package RDF::Query::Algebra::Construct;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.202';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $query_pattern, \@construct_triples ) >>

Returns a new Sort structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $triples	= shift;
	return bless( [ $pattern, $triples ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $triples	= $self->triples;
	return ($pattern, $triples);
}

=item C<< pattern >>

Returns the pattern used to produce the variable bindings used in graph construction.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< triples >>

Returns an ARRAY ref of triples to be used in graph construction.

=cut

sub triples {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	return sprintf(
		'(construct\n${prefix}${indent}%s)',
		$self->pattern->sse( $context, "${prefix}${indent}" ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $triples	= $self->triples;
	my $bgp		= RDF::Query::Algebra::BasicGraphPattern->new( @$triples );
	my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( $bgp );

	my $string	= sprintf(
		"CONSTRUCT %s\n${indent}WHERE %s",
		$ggp->as_sparql( $context, $indent ),
		$self->pattern->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'CONSTRUCT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->referenced_variables);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->binding_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
