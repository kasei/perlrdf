# RDF::Query::Plan::Distinct
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Distinct - Executable query plan for Distincts.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Distinct;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $self	= $class->SUPER::new( $plan );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "DISTINCT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->[0]{seen}	= {};
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in distinct";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open DISTINCT";
	}
	my $plan	= $self->[1];
	while (1) {
		my $row	= $plan->next;
		return undef unless ($row);
		if (not $self->[0]{seen}{ $row->as_string }++) {
			return $row;
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open DISTINCT";
	}
	delete $self->[0]{seen};
	$self->[1]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be made distinct.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 1;
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
	return sprintf("(distinct\n${indent}${more}%s\n${indent}\n${indent})", $self->pattern->sse( $context, "${indent}${more}" ));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	$g->add_node( "$self", label => "Distinct" );
	$g->add_edge( "$self", $c );
	return "$self";
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
