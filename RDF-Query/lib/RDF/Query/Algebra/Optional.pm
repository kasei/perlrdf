# RDF::Query::Algebra::Optional
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Optional - Algebra class for Optional patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Optional version 2.918.

=cut

package RDF::Query::Algebra::Optional;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $pattern, $opt_pattern )>

Returns a new Optional structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $opt		= shift;
	return bless( [ 'OPTIONAL', $pattern, $opt ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern, $self->optional);
}

=item C<< pattern >>

Returns the base pattern (LHS) onto which the optional pattern joins.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< optional >>

Returns the optional pattern (RHS).

=cut

sub optional {
	my $self	= shift;
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	return sprintf(
		"(leftjoin\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		$self->optional->sse( $context, "${prefix}${indent}" )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"%s\n${indent}OPTIONAL %s",
		$self->pattern->as_sparql( $context, $indent ),
		$self->optional->as_sparql( { %$context, force_ggp_braces => 1 }, $indent ),
	);
	return $string;
}

=item C<< as_spin ( $model ) >>

Adds statements to the given model to represent this algebra object in the
SPARQL Inferencing Notation (L<http://www.spinrdf.org/>).

=cut

sub as_spin {
	my $self	= shift;
	my $model	= shift;
	my $spin	= RDF::Trine::Namespace->new('http://spinrdf.org/spin#');
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my @lhs		= $self->pattern->as_spin($model);
	my @rhs		= $self->optional->as_spin($model);
	my $opt		= RDF::Query::Node::Blank->new();
	my $list	= $model->add_list( @rhs );
	$model->add_statement( RDF::Trine::Statement->new($opt, $rdf->type, $spin->Optional) );
	$model->add_statement( RDF::Trine::Statement->new($opt, $spin->elements, $list) );
	return (@lhs, $opt);
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		optional	=> $self->optional->as_hash,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'OPTIONAL';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->referenced_variables, $self->optional->referenced_variables);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->potentially_bound, $self->optional->potentially_bound);
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
