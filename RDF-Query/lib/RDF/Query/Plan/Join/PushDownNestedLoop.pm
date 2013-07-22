# RDF::Query::Plan::Join::PushDownNestedLoop
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join::PushDownNestedLoop - Executable query plan for nested loop joins.

=head1 VERSION

This document describes RDF::Query::Plan::Join::PushDownNestedLoop version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan::Join> class.

=over 4

=cut

package RDF::Query::Plan::Join::PushDownNestedLoop;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join);
use Scalar::Util qw(blessed refaddr);
use Data::Dumper;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
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
	
	if ($rhs->isa('RDF::Query::Plan::SubSelect')) {
		throw RDF::Query::Error::MethodInvocationError -text => "Subselects cannot be the RHS of a PushDownNestedLoop join";
	}
	
	my $opt		= shift || 0;
	if (not($opt) and $rhs->isa('RDF::Query::Plan::Join') and $rhs->optional) {
		# we can't push down results to an optional pattern because of the
		# bottom up semantics. see dawg test algebra/manifest#join-scope-1
		# for example.
		throw RDF::Query::Error::MethodInvocationError -text => "PushDownNestedLoop join does not support optional patterns as RHS due to bottom-up variable scoping rules (use NestedLoop instead)";
	}
	
	if ($rhs->sse =~ /aggregate/sm) {
		throw RDF::Query::Error::MethodInvocationError -text => "PushDownNestedLoop join does not support aggregates in the RHS due to aggregate group fragmentation";
	}
	
	my $self	= $class->SUPER::new( $lhs, $rhs, $opt );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PushDownNestedLoop join plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.join.pushdownnestedloop");
	$l->trace("executing bind join with plans:");
	$l->trace($self->lhs->sse);
	$l->trace($self->rhs->sse);
	
	$self->lhs->execute( $context );
	if ($self->lhs->state == $self->OPEN) {
		delete $self->[0]{stats};
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
				$self->[0]{stats}{outer_rows}++;
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
				$l->trace("exhausted outer plan in bind join");
				return undef;
			}
		}
		
		while (defined(my $inner_row = $self->[0]{inner}->next)) {
			$self->[0]{stats}{inner_rows}++;
			$l->trace( "using inner row: " . $inner_row->as_string );
			if (defined(my $joined = $inner_row->join( $self->[0]{outer_row} ))) {
				$self->[0]{stats}{results}++;
				if ($l->is_trace) {
					$l->trace("joined bindings: $inner_row ⋈ $self->[0]{outer_row}");
				}
#				warn "-> joined\n";
				$self->[0]{inner_count}++;
				if (my $d = $self->delegate) {
					$d->log_result( $self, $joined );
				}
				return $joined;
			} else {
				$l->trace("failed to join bindings: $inner_row |><| $self->[0]{outer_row}");
				if ($opt) {
					$l->trace( "--> but operation is OPTIONAL, so returning $self->[0]{outer_row}" );
					if (my $d = $self->delegate) {
						$d->log_result( $self, $self->[0]{outer_row} );
					}
					return $self->[0]{outer_row};
				}
			}
		}
		
		$self->[0]{needs_new_outer}	= 1;
		if ($self->[0]{inner}->state == $self->OPEN) {
			$self->[0]{inner}->close();
		}
		delete $self->[0]{inner};
		if ($opt and $self->[0]{inner_count} == 0) {
			if (my $d = $self->delegate) {
				$d->log_result( $self, $self->[0]{outer_row} );
			}
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
	if (blessed($self->lhs) and $self->lhs->state == $self->lhs->OPEN) {
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

=item C<< explain >>

Returns a string serialization of the plan appropriate for display on the
command line.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $type	= $self->plan_node_name;
	my $stats	= '';
	if ($self->[0]{stats}) {
		$stats	= sprintf(' [%d/%d/%d]', @{ $self->[0]{stats} }{qw(outer_rows inner_rows results)});
	}
	my $string	= sprintf("%s%s%s (0x%x)\n", $indent, $type, $stats, refaddr($self));
	foreach my $p ($self->plan_node_data) {
		$string	.= $p->explain( $s, $count+1 );
	}
	return $string;
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
