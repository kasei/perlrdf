# RDF::Query::Algebra::Sequence
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Sequence - Algebra class for a sequence of algebra operations

=head1 VERSION

This document describes RDF::Query::Algebra::Sequence version 3.000_01, released 30 January 2010.

=cut

package RDF::Query::Algebra::Sequence;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr reftype);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap swatch);

######################################################################

our ($VERSION);
my %AS_SPARQL;
BEGIN {
	$VERSION	= '3.000_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( @patterns )>

Returns a new Sequence structure.

=cut

sub new {
	my $class	= shift;
	my @patterns	= @_;
	return bless( [ @patterns ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->patterns);
}

=item C<< patterns >>

Returns a list of patterns belonging to this sequence.

=cut

sub patterns {
	my $self	= shift;
	return @$self;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my @patterns	= sort map { $_->sse( $context ) } $self->patterns;
	return sprintf(
		"(sequence\n${prefix}${indent}%s\n${prefix})",
		join("\n${prefix}${indent}", @patterns)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	if (exists $AS_SPARQL{ refaddr( $self ) }) {
		return $AS_SPARQL{ refaddr( $self ) };
	} else {
		my $context	= shift;
# 		if (ref($context)) {
# 			$context	= { %$context };
# 		}
		my $indent	= shift || '';
		my @patterns;
		foreach my $t ($self->patterns) {
			push(@patterns, $t->as_sparql( $context, $indent ));
		}
		my $string	= join(" ;\n${indent}", @patterns);
		$AS_SPARQL{ refaddr( $self ) }	= $string;
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
		patterns	=> [ map { $_->as_hash } $self->patterns ],
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SEQUENCE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->referenced_variables } $self->patterns);
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	my @patterns	= $self->patterns;
	return $patterns[ $#patterns ]->binding_variables;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my @patterns	= $self->patterns;
	return $patterns[ $#patterns ]->binding_variables;
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->patterns );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->patterns );
}

sub DESTROY {
	my $self	= shift;
	delete $AS_SPARQL{ refaddr( $self ) };
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
