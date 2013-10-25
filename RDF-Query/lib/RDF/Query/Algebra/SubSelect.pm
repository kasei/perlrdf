# RDF::Query::Algebra::SubSelect
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::SubSelect - Algebra class for Subselects

=head1 VERSION

This document describes RDF::Query::Algebra::SubSelect version 2.910.

=cut

package RDF::Query::Algebra::SubSelect;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use Log::Log4perl;
use URI::Escape;
use MIME::Base64;
use Data::Dumper;
use RDF::Query::Error;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use Storable qw(store_fd fd_retrieve);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $BLOOM_FILTER_ERROR_RATE);
BEGIN {
	$BLOOM_FILTER_ERROR_RATE	= 0.1;
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $query )>

Returns a new SubSelect structure.

=cut

sub new {
	my $class	= shift;
	my $query	= shift;
	return bless( [ $query ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->query);
}

=item C<< query >>

Returns the sub-select query.

=cut

sub query {
	my $self	= shift;
	if (@_) {
		my $query	= shift;
		$self->[0]	= $query;
	}
	my $query	= $self->[0];
	return $query;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	return $self->query->sse( $context );
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"{ %s }",
		$self->query->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->query->as_hash,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SUBSELECT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @list	= $self->query->pattern->referenced_variables;
	return @list;
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return $self->query->pattern->potentially_bound;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->query->pattern->definite_variables;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
