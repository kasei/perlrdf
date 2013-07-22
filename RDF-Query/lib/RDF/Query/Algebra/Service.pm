# RDF::Query::Algebra::Service
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Service - Algebra class for SERVICE (federation) patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Service version 2.910.

=cut

package RDF::Query::Algebra::Service;

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

=item C<new ( $endpoint, $pattern, $silent )>

Returns a new Service structure.

=cut

sub new {
	my $class		= shift;
	my $endpoint	= shift;
	my $pattern		= shift;
	my $silent		= shift || 0;
	my $ggp			= shift;
	return bless( [ 'SERVICE', $endpoint, $pattern, $silent, $ggp ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->endpoint, $self->pattern, $self->silent, $self->lhs);
}

=item C<< endpoint >>

Returns the endpoint resource of the named graph expression.

=cut

sub endpoint {
	my $self	= shift;
	if (@_) {
		my $endpoint	= shift;
		$self->[1]	= $endpoint;
	}
	my $endpoint	= $self->[1];
	return $endpoint;
}

=item C<< pattern >>

Returns the graph pattern of the named graph expression.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		my $pattern	= shift;
		$self->[2]	= $pattern;
	}
	return $self->[2];
}

=item C<< silent >>

Returns true if the service operation is to ignore errors during execution.

=cut

sub silent {
	my $self	= shift;
	return $self->[3];
}

=item C<< lhs >>

If the SERVCE operation uses a variable endpoint, then it is considered a binary
operator, executing the left-hand-side pattern first, and using results from it
to bind endpoint URL values to use in SERVICE evaluation.

=cut

sub lhs {
	my $self	= shift;
	return $self->[4];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	
	if (my $ggp = $self->lhs) {
		return sprintf(
			"(service\n${prefix}${indent}%s\n${prefix}${indent}%s\n${prefix}${indent}%s)",
			$self->lhs->sse( $context, "${prefix}${indent}" ),
			$self->endpoint->sse( $context, "${prefix}${indent}" ),
			$self->pattern->sse( $context, "${prefix}${indent}" )
		);
	} else {
		return sprintf(
			"(service\n${prefix}${indent}%s\n${prefix}${indent}%s)",
			$self->endpoint->sse( $context, "${prefix}${indent}" ),
			$self->pattern->sse( $context, "${prefix}${indent}" )
		);
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $op		= ($self->silent) ? 'SERVICE SILENT' : 'SERVICE';
	if (my $ggp = $self->lhs) {
		local($context->{skip_filter})	= 0;
		my $string	= sprintf(
			"%s\n${indent}%s %s %s",
			$ggp->as_sparql( $context, $indent ),
			$op,
			$self->endpoint->as_sparql( $context, $indent ),
			$self->pattern->as_sparql( { %$context, force_ggp_braces => 1 }, $indent ),
		);
		return $string;
	} else {
		my $string	= sprintf(
			"%s %s %s",
			$op,
			$self->endpoint->as_sparql( $context, $indent ),
			$self->pattern->as_sparql( { %$context, force_ggp_braces => 1 }, $indent ),
		);
		return $string;
	}
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		endpoint	=> $self->endpoint,
		pattern		=> $self->pattern->as_hash,
		lhs			=> $self->lhs->as_hash,
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SERVICE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @list	= $self->pattern->referenced_variables;
	push(@list, $self->lhs->referenced_variables) if ($self->lhs);
	return RDF::Query::_uniq(@list);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @list	= RDF::Query::_uniq($self->pattern->potentially_bound);
	if ($self->lhs) {
		push(@list, $self->lhs->potentially_bound);
	}
	return @list;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->definite_variables,
		($self->lhs ? $self->lhs->definite_variables : ()),
	);
}


=item C<< qualify_uris ( \%namespaces, $base_uri ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base_uri	= shift;
	
	my $pattern		= $self->pattern->qualify_uris( $ns, $base_uri );
	my $endpoint	= $self->endpoint;
	my $silent		= $self->silent;
	my $uri	= $endpoint->uri;
	if (my $ggp = $self->lhs) {
		return $class->new( $endpoint, $pattern, $silent, $ggp->qualify_uris($ns, $base_uri) );
	} else {
		return $class->new( $endpoint, $pattern, $silent );
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
