# RDF::Query::Algebra::Service
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Service - Algebra class for SERVICE (federation) patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Service version 2.202, released 30 January 2010.

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
	$VERSION	= '2.202';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $endpoint, $pattern )>

Returns a new Service structure.

=cut

sub new {
	my $class		= shift;
	my $endpoint	= shift;
	my $pattern		= shift;
	return bless( [ 'SERVICE', $endpoint, $pattern ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->endpoint, $self->pattern);
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

=item C<< add_bloom ( $variable, $filter ) >>

Adds a FILTER to the enclosed GroupGraphPattern to restrict values of the named
C<< $variable >> to the values encoded in the C<< $filter >> (a
L<Bloom::Filter|Bloom::Filter> object).

=cut

sub add_bloom {
	my $self	= shift;
	my $class	= ref($self);
	my $var		= shift;
	my $bloom	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.algebra.service");
	
	unless (blessed($var)) {
		$var	= RDF::Query::Node::Variable->new( $var );
	}
	
	my $pattern	= $self->pattern;
	my $iri		= RDF::Query::Node::Resource->new('http://kasei.us/code/rdf-query/functions/bloom/filter');
	$l->debug("Adding a bloom filter (with " . $bloom->key_count . " items) function to a remote query");
	my $frozen	= $bloom->freeze;
	my $literal	= RDF::Query::Node::Literal->new( $frozen );
	my $expr	= RDF::Query::Expression::Function->new( $iri, $var, $literal );
	my $filter	= RDF::Query::Algebra::Filter->new( $expr, $pattern );
	return $class->new( $self->endpoint, $filter );
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
		"(service\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->endpoint->sse( $context, "${prefix}${indent}" ),
		$self->pattern->sse( $context, "${prefix}${indent}" )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"SERVICE %s %s",
		$self->endpoint->as_sparql( $context, $indent ),
		$self->pattern->as_sparql( $context, $indent ),
	);
	return $string;
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
	return @list;
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return $self->pattern->binding_variables;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->definite_variables,
	);
}


=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	
	my $pattern	= $self->pattern->qualify_uris( $ns, $base );
	my $endpoint	= $self->endpoint;
	my $uri	= $endpoint->uri;
	return $class->new( $endpoint, $pattern );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
