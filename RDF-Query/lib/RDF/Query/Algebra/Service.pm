# RDF::Query::Algebra::Service
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Service - Algebra class for SERVICE (federation) patterns

=cut

package RDF::Query::Algebra::Service;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);
use constant DEBUG	=> 0;

use Data::Dumper;
use RDF::Query::Error;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(sgrep smap swatch);

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
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(service %s %s)',
		$self->endpoint->sse( $context ),
		$self->pattern->sse( $context )
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

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(
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


=item C<< fixup ( $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	my $endpoint	= ($self->endpoint->isa('RDF::Query::Node'))
				? $bridge->as_native( $self->endpoint )
				: $self->endpoint->fixup( $bridge, $base, $ns );
	
	return $class->new( $endpoint, map { $_->fixup( $bridge, $base, $ns ) } ($self->pattern) );
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $outer_ctx	= shift;
	my %args		= @_;
	
	if ($outer_ctx) {
		throw RDF::Query::Error::QueryPatternError ( -text => "Can't use nested SERVICE graphs" );
	}

	my $context			= $self->endpoint;
	my $named_triples	= $self->pattern;
	
	throw RDF::Query::Error -text => "SERVICE queries not yet implemented";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
