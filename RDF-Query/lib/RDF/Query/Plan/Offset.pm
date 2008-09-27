# RDF::Query::Plan::Offset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Offset - Executable query plan for Offsets.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Offset;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan, $offset ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $offset	= shift;
	my $self	= $class->SUPER::new( $plan, $offset );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "OFFSET plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
		for (my $i = 0; $i < $self->offset; $i++) {
			my $row	= $plan->next;
		}
	} else {
		warn "could not execute plan in OFFSET";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open OFFSET";
	}
	my $plan	= $self->[1];
	my $row		= $plan->next;
	return undef unless ($row);
	return $row;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open OFFSET";
	}
	$self->[1]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be offset.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< offset >>

Returns the number of results that are discarded as offset.

=cut

sub offset {
	my $self	= shift;
	return $self->[2];
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
	return sprintf("(offset\n${indent}${more}%s\n${indent}${more}%s\n${indent})", $self->[2], $self->pattern->sse( $context, "${indent}${more}" ));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	$g->add_node( "$self", label => "Offset ($self->[2])" . $self->graph_labels );
	$g->add_edge( "$self", $c );
	return "$self";
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
