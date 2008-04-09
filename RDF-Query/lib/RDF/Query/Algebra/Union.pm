# RDF::Query::Algebra::Union
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Union - Algebra class for Union patterns

=cut

package RDF::Query::Algebra::Union;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $left, $right )>

Returns a new Union structure.

=cut

sub new {
	my $class	= shift;
	my $left	= shift;
	my $right	= shift;
	return bless( [ 'UNION', $left, $right ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->first, $self->second);
}

=item C<< first >>

Returns the first pattern (LHS) of the union.

=cut

sub first {
	my $self	= shift;
	return $self->[1];
}

=item C<< second >>

Returns the second pattern (RHS) of the union.

=cut


=item C<< patterns >>

Returns the two patterns belonging to the UNION pattern.

=cut

sub patterns {
	my $self	= shift;
	return ($self->first, $self->second);
}

sub second {
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
		'(union %s %s)',
		$self->first->sse( $context ),
		$self->second->sse( $context )
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
		"%s\n${indent}UNION\n${indent}%s",
		$self->first->as_sparql( $context, $indent ),
		$self->second->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'UNION';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq($self->first->referenced_variables, $self->second->referenced_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my $seta	= Set::Scalar->new( $self->first->definite_variables );
	my $setb	= Set::Scalar->new( $self->second->definite_variables );
	return $seta->intersection( $setb )->members;
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		return $class->new( map { $_->fixup( $query, $bridge, $base, $ns ) } $self->patterns );
	}
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	
	my @names;
	my @streams;
	foreach my $u_triples ($self->first, $self->second) {
		my $stream	= $u_triples->execute( $query, $bridge, $bound, $context, %args );
		
		if ($debug) {
			$stream		= $stream->materialize;
			warn "union stream:\n";
			while (my $b = $stream->next) {
				warn "BINDING: " . join(', ', map { my $v = $b->{$_}; join('=', $_, (blessed($v) ? $v->sse : '')) } (keys %$b));
			}
			$stream->reset;
		}
		
		push(@names, $stream->binding_names);
		push(@streams, $stream);
	}
	
	@streams	= map { $_->project( @names ) } @streams;
	my $stream	= shift(@streams);
	while (@streams) {
		$stream	= $stream->concat( shift(@streams), undef, \@names );
	}
	
	return $stream;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
