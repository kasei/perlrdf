# RDF::Query::Algebra::Update
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Update - Algebra class for UPDATE operations

=head1 VERSION

This document describes RDF::Query::Algebra::Update version 2.202, released 30 January 2010.

=cut

package RDF::Query::Algebra::Update;

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

=item C<new ( $delete_template, $insert_template, $pattern )>

Returns a new UPDATE structure.

=cut

sub new {
	my $class	= shift;
	my $delete	= shift;
	my $insert	= shift;
	my $pat		= shift;
	return bless([$delete, $insert, $pat], $class);
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->delete_template, $self->insert_template, $self->pattern);
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $string;
	my $delete	= $self->delete_template;
	my $insert	= $self->insert_template;
	return sprintf(
		"(update (delete %s) (insert %s) (where %s))",
		($delete ? $delete->sse( $context, $indent ) : ''),
		($insert ? $insert->sse( $context, $indent ) : ''),
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
	my $delete	= $self->delete_template;
	my $insert	= $self->insert_template;
	my $ggp		= $self->pattern;
	my @pats	= $ggp->patterns;
	if (not($insert) or not($delete)) {
		my $op		= ($delete) ? 'DELETE' : 'INSERT';
		my $temp	= ($delete) ? $delete : $insert;
		if (scalar(@pats) == 0) {
			return sprintf(
				"${op} DATA {\n${indent}	%s\n${indent}}",
				$temp->as_sparql( $context, "${indent}	" )
			);
		} else {
			return sprintf(
				"${op} {\n${indent}	%s\n${indent}} WHERE %s",
				$temp->as_sparql( $context, "${indent}	" ),
				$ggp->as_sparql( $context, "${indent}" ),
			);
		}
	} else {
		return sprintf(
			"DELETE {\n${indent}	%s\n${indent}}\n${indent}INSERT {\n${indent}	%s\n${indent}}\n${indent}WHERE %s",
			$delete->as_sparql( $context, "${indent}  " ),
			$insert->as_sparql( $context, "${indent}  " ),
			$ggp->as_sparql( $context, ${indent} ),
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

=item C<< delete_template >>

=cut

sub delete_template {
	my $self	= shift;
	return $self->[0];
}

=item C<< insert_template >>

=cut

sub insert_template {
	my $self	= shift;
	return $self->[1];
}

=item C<< pattern >>

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
