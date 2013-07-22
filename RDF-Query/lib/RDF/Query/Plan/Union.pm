# RDF::Query::Plan::Union
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Union - Executable query plan for unions.

=head1 VERSION

This document describes RDF::Query::Plan::Union version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Union;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed refaddr);

use RDF::Query::ExecutionContext;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $lhs, $rhs ) >>

=cut

sub new {
	my $class	= shift;
	my ($lhs, $rhs)	= @_;
	my $self	= $class->SUPER::new( [ $lhs, $rhs ] );
	my %vars;
	foreach my $v ($lhs->referenced_variables, $rhs->referenced_variables) {
		$vars{ $v }++;
	}
	$self->[0]{referenced_variables}	= [ keys %vars ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "BGP plan can't be executed while already open";
	}
	
	my $iter	= $self->[1][0];
	$iter->execute( $context );
	
	if ($iter->state == $self->OPEN) {
		$self->[0]{iter}	= $iter;
		$self->[0]{idx}		= 0;
		$self->[0]{context}	= $context;
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
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.union");
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open BGP";
	}
	my $iter	= $self->[0]{iter};
	return undef unless ($iter);
	my $row		= $iter->next;
	if (defined($row)) {
		$l->trace( "union row: $row" );
		if (my $d = $self->delegate) {
			$d->log_result( $self, $row );
		}
		return $row;
	} else {
		$self->[0]{iter}	= undef;
		if ($self->[0]{idx} < $#{ $self->[1] }) {
			$iter->close();
			$self->[0]{idx}++;
			my $index	= $self->[0]{idx};
			my $iter	= $self->[1][ $index ];
			$iter->execute( $self->[0]{context} );
			if ($iter->state == $self->OPEN) {
				$l->trace( "union moving to next branch" );
				$self->[0]{iter}	= $iter;
				my $bindings	= $self->next;
				if (my $d = $self->delegate) {
					$d->log_result( $self, $bindings );
				}
				return $bindings;
			} else {
				throw RDF::Query::Error::ExecutionError -text => "execute() on RHS of UNION failed during next()";
			}
		} else {
			$l->trace( "union reached end of last branch" );
			$iter->close();
			delete $self->[0]{iter};
			return undef;
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open BGP";
	}
	if (my $iter = $self->[0]{iter}) {
		$iter->close();
		delete $self->[0]{iter};
		delete $self->[0]{idx};
	}
	$self->SUPER::close();
}

=item C<< lhs >>

Returns the left-hand-side plan to the union.

=cut

sub lhs {
	my $self	= shift;
	return $self->[1][0];
}

=item C<< rhs >>

Returns the right-hand-side plan to the union.

=cut

sub rhs {
	my $self	= shift;
	return $self->[1][1];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'union';
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
	my $expr	= $self->[2];
	return ($self->lhs, $self->rhs);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my ($l, $r)	= map { $_->graph( $g ) } ($self->lhs, $self->rhs);
	$g->add_node( "$self", label => "Union" . $self->graph_labels );
	$g->add_edge( "$self", $l );
	$g->add_edge( "$self", $r );
	return "$self";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
