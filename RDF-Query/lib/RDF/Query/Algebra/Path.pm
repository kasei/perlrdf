# RDF::Query::Algebra::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Path - Algebra class for path patterns

=cut

package RDF::Query::Algebra::Path;

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
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $start, [ $op, @paths ], $end )>

Returns a new Path structure.

=cut

sub new {
	my $class	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	return bless( [ $start, $path, $end ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->start, $self->path, $self->end);
}

=item C<< path >>

Returns the path description for this path expression.

=cut

sub path {
	my $self	= shift;
	return $self->[1];
}

=item C<< start >>

Returns the path origin node.

=cut

sub start {
	my $self	= shift;
	return $self->[0];
}

=item C<< end >>

Returns the path destination node.

=cut

sub end {
	my $self	= shift;
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	die 'SSE serialization of path expressions not implemented';
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	die 'SPARQL serialization of path expressions not implemented';
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
	return 'PATH';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= grep { $_->isa('RDF::Query::Node::Variable') } ($self->start, $self->end);
	return uniq(map { $_->name } @vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->referenced_variables;
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
		my ($start, $end)	= map { $_->fixup( $query, $bridge, $base, $ns ) } ($self->start, $self->end);
		my $path			= $self->path;
		return $class->new( $start, $path, $end );
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
	
	my $start		= $self->start;
	my $end			= $self->end;
	my $path		= $self->path;
	
	return $self->match_path( $query, $bridge, $bound, $context, $start, $path, $end );
}

=item C<< match_path ( $query, $bridge, \%bound, $context, $current_node, $path, $end_node ) >>

=cut

sub match_path {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my $current		= shift;
	my $path		= shift;
	my $end			= shift;
	
	if (blessed($path) and $path->isa('RDF::Query::Node')) {
		my $triple	= RDF::Query::Algebra::Triple->new( $current, $path, $end );
		return $triple->execute( $query, $bridge, $bound, $context );
	} else {
		my ($op, @args)	= @$path;
		if ($op eq '/') {
			my ($a, $b)	= @args;
			my $connect_var	= RDF::Query::Node::Variable->new();
			warn $connect_var;
			my $streama	= $self->match_path( $query, $bridge, $bound, $context, $current, $a, $connect_var );
			my $streamb	= $self->match_path( $query, $bridge, $bound, $context, $connect_var, $b, $end );
			my $stream	= RDF::Trine::Iterator::Bindings->join_streams( $streama, $streamb );
			return $stream;
		} else {
			warn "unknown path op $op";
		}
	}
	
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
