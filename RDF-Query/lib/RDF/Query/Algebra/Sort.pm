# RDF::Query::Algebra::Sort
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Sort - Algebra class for sorting

=head1 VERSION

This document describes RDF::Query::Algebra::Sort version 2.918.

=cut

package RDF::Query::Algebra::Sort;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);

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

=item C<new ( $pattern, [ $dir => $expr ] )>

Returns a new Sort structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my @orderby	= @_;
	return bless( [ $pattern, @orderby ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my @orderby	= $self->orderby;
	return ($pattern, @orderby);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< orderby >>

Returns the array of ordering definitions.

=cut

sub orderby {
	my $self	= shift;
	my @orderby	= @{ $self }[ 1 .. $#{ $self } ];
	return @orderby;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my @order_sse;
	my @orderby	= $self->orderby;
	foreach my $o (@orderby) {
		my ($dir, $val)	= @$o;
		push(@order_sse, sprintf("($dir %s)", $val->sse( $context, "${prefix}${indent}" )));
	}
	
	return sprintf(
		"(sort\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		join(' ', @order_sse),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	
	if ($context->{ skip_sort }) {
		$context->{ skip_sort }--;
		return $self->pattern->as_sparql( $context, $indent );
	}
	
	my $order_exprs	= $self->_as_sparql_order_exprs($context, $indent);
	
	my $string	= sprintf(
		"%s\nORDER BY %s",
		$self->pattern->as_sparql( $context, $indent ),
		$order_exprs,
	);
	return $string;
}

sub _as_sparql_order_exprs {
	my $self	= shift;
	my $context	= shift;
	my $intent	= shift;
	
	my @order_sparql;
	my @orderby	= $self->orderby;
	foreach my $o (@orderby) {
		my ($dir, $val)	= @$o;
		$dir			= uc($dir);
		my $str			= ($dir eq 'ASC')
						? $val->as_sparql( $context )
						: sprintf("%s(%s)", $dir, $val->as_sparql( $context ));
		push(@order_sparql, $str);
	}
	return join(' ', @order_sparql);
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	
	my @order	= $self->orderby;
	my @expressions;
	foreach my $o (@order) {
		push(@expressions, { type => 'comparator', direction => $o->[0], expression => $o->[1]->as_hash });
	}
	
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		order		=> \@expressions,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SORT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->referenced_variables);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return RDF::Query::_uniq($self->pattern->potentially_bound);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
