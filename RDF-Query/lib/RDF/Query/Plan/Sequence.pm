# RDF::Query::Plan::Sequence
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Sequence - Executable query plan for a sequence of operations.

=head1 VERSION

This document describes RDF::Query::Plan::Sequence version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Sequence;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Trine::Statement;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( @plans ) >>

=cut

sub new {
	my $class	= shift;
	my @plans	= @_;
	my $self	= $class->SUPER::new( \@plans );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "SEQUENCE plan can't be executed twice";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.sequence");
	$l->trace( "executing RDF::Query::Plan::Sequence" );
	
	my @plans	= @{ $self->[1] };
	while (scalar(@plans) > 1) {
		my $p	= shift(@plans);
		$p->execute( $context );
		1 while ($p->next);
	}
	my $iter	= $plans[0]->execute( $context );
	
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open SEQUENCE";
	}
	
	my $iter	= $self->[0]{iter};
	my $row		= $iter->next;
	if (my $d = $self->delegate) {
		$d->log_result( $self, $row );
	}
	return $row;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open SEQUENCE";
	}
	
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	my @plans	= @{ $self->[1] };
	return $plans[ $#plans ]->distinct;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	my @plans	= @{ $self->[1] };
	return $plans[ $#plans ]->ordered;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'sequence';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(*P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my @triples	= @{ $self->[1] };
	return @triples;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
