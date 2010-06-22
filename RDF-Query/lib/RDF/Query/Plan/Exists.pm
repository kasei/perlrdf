# RDF::Query::Plan::Exists
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Exists - Executable query plan for EXISTS blocks.

=head1 VERSION

This document describes RDF::Query::Plan::Exists version 3.000_01, released 30 January 2010.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Exists;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '3.000_01';
}

######################################################################

=item C<< new ( $plan, $exists_plan, $not_flag ) >>

=cut

sub new {
	my $class		= shift;
	my $plan		= shift;
	my $exists_plan	= shift;
	my $not_flag	= shift;
	my $self	= $class->SUPER::new( $plan, $exists_plan, $not_flag );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables, $exists_plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "EXISTS plan can't be executed while already open";
	}
	my $plan	= $self->pattern;
	$plan->execute( $context );
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.exists");
	
	if ($plan->state == $self->OPEN) {
		$self->[0]{context}			= $context;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in not";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open EXISTS";
	}
	my $plan	= $self->pattern;
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.exists");
	my $context	= $self->[0]{context};
	
	my $not		= $self->not_flag;
	while (1) {
		my $row	= $plan->next;
		unless ($row) {
			$l->debug("no remaining rows in EXISTS");
			return;
		}
		$l->debug("EXISTS processing bindings $row");
		my $npattern	= $self->exists_pattern;
		my $copy		= $context->copy( bound => $row );
		$npattern->execute( $copy );
		if ($npattern->state == $npattern->OPEN) {
			if ($npattern->next) {
				if ($not) {
					$npattern->close();
					$l->debug( "- NOT EXISTS found row, going to next result..." );
				} else {
					$l->debug( "- EXISTS found row, returning result..." );
					$npattern->close();
					return $row;
				}
			} else {
				if ($not) {
					$l->debug( "- NOT EXISTS didn't find any rows, returning result..." );
					$npattern->close();
					return $row;
				} else {
					$npattern->close();
					$l->debug( "- EXISTS didn't find any rows, going to next result..." );
				}
			}
		} else {
			warn "could not execute EXISTS-plan in EXISTS";
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open EXISTS";
	}
	delete $self->[0]{filter};
	if ($self->[2]->state == $self->[2]->OPEN) {
		$self->[2]->close();
	}
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be filtered.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< exists_pattern >>

Returns the query plan that will be used as the negated pattern.

=cut

sub exists_pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< not_flag >>

Returns true if the EXISTS plan represents a negative query (NOT EXISTS).

=cut

sub not_flag {
	my $self	= shift;
	return $self->[3];
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

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	my $self	= shift;
	return ($self->not_flag) ? 'not-exists' : 'exists';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $expr	= $self->[1];
	return ($self->pattern, $self->exists_pattern, $self->not_flag);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
