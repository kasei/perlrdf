# RDF::Query::Plan::Join::PushDownNestedLoop
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join::PushDownNestedLoop - Executable query plan for nested loop joins.

=head1 VERSION

This document describes RDF::Query::Plan::Join::PushDownNestedLoop version 3.000_01, released 30 January 2010.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join::PushDownNestedLoop;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join);
use Scalar::Util qw(blessed);
use Data::Dumper;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '3.000_01';
	$RDF::Query::Plan::Join::JOIN_CLASSES{ 'RDF::Query::Plan::Join::PushDownNestedLoop' }++;
}

######################################################################

use RDF::Query::ExecutionContext;

=item C<< new ( $lhs, $rhs, $opt ) >>

=cut

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	
	my $opt		= shift || 0;
	if (not($opt) and $rhs->isa('RDF::Query::Plan::Join') and $rhs->optional) {
		# we can't push down results to an optional pattern because of the
		# bottom up semantics. see dawg test algebra/manifest#join-scope-1
		# for example.
		throw RDF::Query::Error::MethodInvocationError -text => "PushDownNestedLoop join does not support optional patterns as RHS due to bottom-up variable scoping rules (use NestedLoop instead)";
	}
	my $self	= $class->SUPER::new( $lhs, $rhs, $opt );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PushDownNestedLoop join plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.join.pushdownnestedloop");
	$l->trace("executing bind join");
	
	$self->lhs->execute( $context );
	if ($self->lhs->state == $self->OPEN) {
		$self->[0]{context}			= $context;
		$self->[0]{outer}			= $self->lhs;
		$self->[0]{needs_new_outer}	= 1;
		$self->[0]{inner_count}		= 0;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
#	warn '########################################';
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PushDownNestedLoop join";
	}
	my $outer	= $self->[0]{outer};
	my $inner	= $self->rhs;
	my $opt		= $self->[3];
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.join.pushdownnestedloop");
	while (1) {
		if ($self->[0]{needs_new_outer}) {
			$self->[0]{outer_row}	= $outer->next;
			my $outer	= $self->[0]{outer_row};
			if (ref($outer)) {
				my $context	= $self->[0]{context};
				$self->[0]{needs_new_outer}	= 0;
				$self->[0]{inner_count}		= 0;
				if ($self->[0]{inner}) {
					$self->[0]{inner}->close();
				}
				my %bound	= %{ $context->bound };
				@bound{ keys %$outer }	= values %$outer;
				my $copy	= $context->copy( bound => \%bound );
				$l->trace( "executing inner plan with bound: " . Dumper(\%bound) );
				if ($inner->state == $inner->OPEN) {
					$inner->close();
				}
				$self->[0]{inner}			= $inner->execute( $copy );
			} else {
				# we've exhausted the outer iterator. we're now done.
				$l->trace("exhausted");
				return undef;
			}
		}
		
		while (defined(my $inner_row = $self->[0]{inner}->next)) {
			$l->trace( "using inner row: " . Dumper($inner_row) );
			if (defined(my $joined = $inner_row->join( $self->[0]{outer_row} ))) {
				if ($l->is_trace) {
					$l->trace("joined bindings: $inner_row |><| $self->[0]{outer_row}");
				}
#				warn "-> joined\n";
				$self->[0]{inner_count}++;
				return $joined;
			} else {
				if ($opt) {
					return $self->[0]{outer_row};
				}
				$l->trace("failed to join bindings: $inner_row |><| $self->[0]{outer_row}");
			}
		}
		
		$self->[0]{needs_new_outer}	= 1;
		if ($self->[0]{inner}->state == $self->OPEN) {
			$self->[0]{inner}->close();
		}
		delete $self->[0]{inner};
		if ($opt and $self->[0]{inner_count} == 0) {
			return $self->[0]{outer_row};
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PushDownNestedLoop join";
	}
	delete $self->[0]{inner};
	delete $self->[0]{outer};
	delete $self->[0]{needs_new_outer};
	delete $self->[0]{inner_count};
	if ($self->lhs->state == $self->lhs->OPEN) {
		$self->lhs->close();
	}
	$self->SUPER::close();
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	my $self	= shift;
	my $jtype	= $self->optional ? 'leftjoin' : 'join';
	return "bind-$jtype";
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $jtype	= $self->optional ? 'Left Join' : 'Join';
	my ($l, $r)	= map { $_->graph( $g ) } ($self->lhs, $self->rhs);
	$g->add_node( "$self", label => "$jtype (Bind)" . $self->graph_labels );
	$g->add_edge( "$self", $l );
	$g->add_edge( "$self", $r );
	return "$self";
}


package RDF::Query::Plan::Join::PushDownNestedLoop::Left;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join::PushDownNestedLoop);

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	return $class->SUPER::new( $lhs, $rhs, 1 );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
