# RDF::Query::Algebra::Delete
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Delete - Algebra class for DELETE operations

=head1 VERSION

This document describes RDF::Query::Algebra::Delete version 2.202, released 30 January 2010.

=cut

package RDF::Query::Algebra::Delete;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %TRIPLE_LABELS;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.202';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $template, $pattern )>

Returns a new DELETE structure.

=cut

sub new {
	my $class	= shift;
	my $temp	= shift;
	my $pat		= shift;
	return bless([$temp, $pat], $class);
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->template, $self->pattern);
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $string;
	return sprintf(
		"(delete <%s> <%s>)",
		$self->template->sse( $context, $indent ),
		$self->pattern->sse( $context, $indent ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift || '';
	my $temp	= $self->template;
	my @pats	= $self->pattern->patterns;
	if (scalar(@pats) == 0) {
		return sprintf(
			"DELETE DATA {\n${indent}	%s\n${indent}}",
			$temp->as_sparql( $context, "${indent}	" )
		);
	} else {
		my $ggp	= $self->pattern;
		return sprintf(
			"DELETE {\n${indent}	%s\n${indent}} WHERE %s",
			$temp->as_sparql( $context, "${indent}	" ),
			$ggp->as_sparql( $context, "${indent}" ),
		);
	}
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	return;
}

=item C<< referenced_variables >>

=cut

sub referenced_variables {
	my $self	= shift;
	return;
}

=item C<< template >>

=cut

sub template {
	my $self	= shift;
	return $self->[0];
}

=item C<< pattern >>

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
