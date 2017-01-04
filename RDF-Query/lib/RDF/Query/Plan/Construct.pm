# RDF::Query::Plan::Construct
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Construct - Executable query plan for constructing a graph from a set of variable bindings.

=head1 VERSION

This document describes RDF::Query::Plan::Construct version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Construct;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=item C<< new ( $plan, \@triples ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $triples	= shift;
	
	unless (@$triples) {
		throw RDF::Query::Error::MethodInvocationError -text => "No triples passed to ::Plan::Construct constructor";
	}
	
	my $self	= $class->SUPER::new( $plan, $triples );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "CONSTRUCT plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.construct");
	$l->trace( "executing RDF::Query::Plan::Construct" );
	
	my $plan	= $self->pattern;
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->[0]{triples}		= [];
		$self->[0]{blank_map}	= {};
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in construct";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open CONSTRUCT";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	my $plan	= $self->[1];
	while (1) {
		while (scalar(@{ $self->[0]{triples} })) {
			my $t	= shift(@{ $self->[0]{triples} });
			if (my $d = $self->delegate) {
				$d->log_result( $self, $t );
			}
			return $t;
		}
		my $row	= $plan->next;
		return undef unless ($row);
		$self->[0]{blank_map}	= {};
		
		if ($l->is_debug) {
			$l->debug( "- got construct bindings from pattern: " . $row->as_string );
		}
		my $triples	= $self->triples;
		
		foreach my $t (@$triples) {
			if ($l->is_debug) {
				$l->debug( "- filling-in construct triple pattern: " . $t->as_string );
			}
			my @triple	= $t->nodes;
			for my $i (0 .. 2) {
				if ($triple[$i]->isa('RDF::Trine::Node::Variable')) {
					my $name	= $triple[$i]->name;
					$triple[$i]	= $row->{ $name };
				} elsif ($triple[$i]->isa('RDF::Trine::Node::Blank')) {
					my $id	= $triple[$i]->blank_identifier;
					unless (exists($self->[0]{blank_map}{ $id })) {
						$self->[0]{blank_map}{ $id }	= RDF::Trine::Node::Blank->new();
					}
					$triple[$i]	= $self->[0]{blank_map}{ $id };
				}
			}
			my $ok	= 1;
			foreach (@triple) {
				if (not blessed($_)) {
					$ok	= 0;
				}
			}
			next unless ($ok);
			my $st	= RDF::Trine::Statement->new( @triple );
			unless ($self->[0]{seen}{ $st->as_string }++) {
				push(@{ $self->[0]{triples} }, $st);
			}
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open CONSTRUCT";
	}
	delete $self->[0]{blank_map};
	delete $self->[0]{triples};
	
	if ($self->[1] and $self->[1]->state == $self->OPEN) {
		$self->[1]->close();
	}
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the variable bindings for constructing the new graph.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< triples >>

Returns the triples that are to be used in constructing the new graph for each variable binding.

=cut

sub triples {
	my $self	= shift;
	return $self->[2];
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
	my $self	= shift;
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'construct';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P \T);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->pattern, [ @{ $self->triples } ]);
}

=item C<< explain >>

Returns a string serialization of the query plan appropriate for display
on the command line.

=cut

sub explain {
	my $self	= shift;
	my ($s, $count)	= ('  ', 0);
	if (@_) {
		$s		= shift;
		$count	= shift;
	}
	my $indent	= '' . ($s x $count);
	my $type	= $self->plan_node_name;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self));
	$string		.= $self->pattern->explain( $s, $count+1 );
	$string		.= "${indent}${s}pattern\n";
	foreach my $t (@{ $self->triples }) {
		$string		.= "${indent}${s}${s}" . $t->as_sparql . "\n";
	}
	return $string;
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	$g->add_node( "$self", label => "Construct" . $self->graph_labels );
	$g->add_edge( "$self", $c );
	return "$self";
}

=item C<< as_iterator ( $context ) >>

Returns an RDF::Trine::Iterator object for the current (already executed) plan.

=cut

sub as_iterator {
	my $self	= shift;
	my $context	= shift;
	my $stream	= RDF::Trine::Iterator::Graph->new( sub { $self->next } );
	return $stream;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
