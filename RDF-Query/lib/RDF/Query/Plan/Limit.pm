# RDF::Query::Plan::Limit
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Limit - Executable query plan for Limits.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Limit;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan, $limit ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $limit	= shift;
	my $self	= $class->SUPER::new( $plan, $limit );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "LIMIT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
		$self->[0]{count}	= 0;
	} else {
		warn "could not execute plan in LIMIT";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open LIMIT";
	}
	return undef if ($self->[0]{count} >= $self->[2]);
	my $plan	= $self->[1];
	my $row		= $plan->next;
	return undef unless ($row);
	$self->[0]{count}++;
	return $row;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open LIMIT";
	}
	delete $self->[0]{count};
	$self->[1]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be filtered.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	return $self->pattern->distinct;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	return $self->pattern->ordered;
}

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf("(limit\n${indent}${more}%s\n${indent}${more}%s\n${indent})", $self->[2], $self->pattern->sse( $context, "${indent}${more}" ));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	$g->add_node( "$self", label => "Limit ($self->[2])" );
	$g->add_edge( "$self", $c );
	return "$self";
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
