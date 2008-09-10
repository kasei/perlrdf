# RDF::Query::Plan::Join::NestedLoop
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join::NestedLoop - Executable query plan for nested loop joins.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join::NestedLoop;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::Error qw(:try);

BEGIN {
	$RDF::Query::Plan::Join::JOIN_CLASSES{ 'RDF::Query::Plan::Join::NestedLoop' }++;
}

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( $lhs, $rhs, $opt, [ \%logging_keys ] ) >>

=cut

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	my $opt		= shift;
	my $keys	= shift;
	if ($opt) {
		throw RDF::Query::Error::MethodInvocationError -text => "NestedLoop join does not support optional joins (use PushDownNestedLoop instead)";
	}
	my $self	= $class->SUPER::new( $lhs, $rhs, $opt );
	
	$self->[0]{logging_keys}	= $keys;
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "NestedLoop join plan can't be executed while already open";
	}
	
	$self->[0]{start_time}	= [gettimeofday];
	my @inner;
	$self->rhs->execute( $context );
	while (my $row = $self->rhs->next) {
#		warn "*** loading inner row cache with: " . Dumper($row);
		push(@inner, $row);
	}
	$self->lhs->execute( $context );
	if ($self->lhs->state == $self->OPEN) {
		$self->[0]{inner}			= \@inner;
		$self->[0]{outer}			= $self->lhs;
		$self->[0]{inner_index}		= 0;
		$self->[0]{needs_new_outer}	= 1;
		$self->[0]{inner_count}		= 0;
		$self->[0]{count}			= 0;
		$self->[0]{logger}			= $context->logger;
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open NestedLoop join";
	}
	my $outer	= $self->[0]{outer};
	my $inner	= $self->[0]{inner};
	
	while (1) {
		if ($self->[0]{needs_new_outer}) {
			$self->[0]{outer_row}	= $outer->next;
			if (ref($self->[0]{outer_row})) {
				$self->[0]{needs_new_outer}	= 0;
				$self->[0]{inner_index}		= 0;
				$self->[0]{inner_count}		= 0;
	#			warn "got new outer row: " . Dumper($self->[0]{outer_row});
			} else {
				# we've exhausted the outer iterator. we're now done.
	#			warn "exhausted";
				return undef;
			}
		}
		
		while ($self->[0]{inner_index} < scalar(@$inner)) {
			my $inner_row	= $inner->[ $self->[0]{inner_index}++ ];
	#		warn "using inner row: " . Dumper($inner_row);
			if (my $joined = $inner_row->join( $self->[0]{outer_row} )) {
#				warn "-> joined\n";
				$self->[0]{inner_count}++;
				$self->[0]{count}++;
				return $joined;
			} else {
#				warn "-> didn't join\n";
			}
		}
		
		$self->[0]{needs_new_outer}	= 1;
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open NestedLoop join";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.join.nestedloop");
	my $t0		= delete $self->[0]{start_time};
	my $count	= delete $self->[0]{count};
	if (my $log = delete $self->[0]{logger}) {
		$l->debug("logging nestedloop join execution statistics");
		my $elapsed = tv_interval ( $t0 );
		if (my $sparql = $self->logging_keys->{sparql}) {
			$l->debug("- SPARQL: $sparql");
			$log->push_key_value( 'execute_time-nestedloop', $sparql, $elapsed );
			$log->push_key_value( 'cardinality-nestedloop', $sparql, $count );
			$l->debug("- elapsed: $elapsed");
			$l->debug("- count: $count");
		}
		if (my $bf = $self->logging_keys->{bf}) {
			$l->debug("- bf: $bf");
			$log->push_key_value( 'cardinality-bf-nestedloop', $bf, $count );
		}
	}
	delete $self->[0]{inner};
	delete $self->[0]{outer};
	delete $self->[0]{inner_index};
	delete $self->[0]{needs_new_outer};
	delete $self->[0]{inner_count};
	$self->lhs->close();
	$self->rhs->close();
	$self->SUPER::close();
}

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	my $jtype	= $self->optional ? 'leftjoin' : 'join';
	return sprintf("(nestedloop-${jtype}\n${indent}${more}%s\n${indent}${more}%s\n${indent})", $self->lhs->sse( $context, "${indent}${more}" ), $self->rhs->sse( $context, "${indent}${more}" ));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my ($l, $r)	= map { $_->graph( $g ) } ($self->lhs, $self->rhs);
	$g->add_node( "$self", label => "Join (NL)" );
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
