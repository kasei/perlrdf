# RDF::Query::Plan::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::BasicGraphPattern - Executable query plan for BasicGraphPatterns.

=head1 VERSION

This document describes RDF::Query::Plan::BasicGraphPattern version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::BasicGraphPattern;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Trine::Statement;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=item C<< new ( @triples ) >>

=cut

sub new {
	my $class	= shift;
	my @triples	= map {
					my @nodes	= $_->nodes;
					$nodes[3]	||= RDF::Trine::Node::Nil->new();
					(scalar(@nodes) == 4)
						? RDF::Trine::Statement::Quad->new( @nodes )
						: RDF::Trine::Statement->new( @nodes )
				} @_;
	my @vars	= map { $_->name } grep { $_->isa('RDF::Trine::Node::Variable') } map { $_->nodes } @triples;
	my @uvars	= keys %{ { map { $_ => 1 } @vars } };
	my $self	= $class->SUPER::new( \@triples );
	$self->[0]{referenced_variables}	= \@uvars;
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "BGP plan can't be executed twice";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.basicgraphpattern");
	$l->trace( "executing RDF::Query::Plan::BasicGraphPattern" );
	
	my @bound_triples;
	my $bound	= $context->bound;
	if (%$bound) {
		$self->[0]{bound}	= $bound;
		my @triples	= @{ $self->[1] };
		foreach my $j (0 .. $#triples) {
			my @nodes	= $triples[$j]->nodes;
			foreach my $i (0 .. $#nodes) {
				next unless ($nodes[$i]->isa('RDF::Trine::Node::Variable'));
				next unless (blessed($bound->{ $nodes[$i]->name }));
# 				warn "pre-bound variable found: " . $nodes[$i]->name;
				$nodes[$i]	= $bound->{ $nodes[$i]->name };
			}
			my $triple	= (scalar(@nodes) == 4)
						? RDF::Trine::Statement::Quad->new( @nodes )
						: RDF::Trine::Statement->new( @nodes );
			push(@bound_triples, $triple);
		}
	} else {
		@bound_triples	= @{ $self->[1] };
	}
	
	my @tmp		= grep { $_->isa('RDF::Trine::Statement::Quad') and $_->context->isa('RDF::Trine::Node::Variable') } @bound_triples;
	my $quad	= scalar(@tmp) ? $tmp[0]->context : undef;
	
	my $model	= $context->model;
	my $pattern	= RDF::Trine::Pattern->new( @bound_triples );
	$l->trace( "BGP: " . $pattern->sse );
	my $iter	= $model->get_pattern( $pattern );
	
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->[0]{quad}	= $quad;
		$self->[0]{nil}		= RDF::Trine::Node::Nil->new();
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open BGP";
	}
	
	my $q	= $self->[0]{quad};
	
	my $iter	= $self->[0]{iter};
	return undef unless ($iter);
	while (ref(my $row = $iter->next)) {
		if (ref(my $bound = $self->[0]{bound})) {
			@{ $row }{ keys %$bound }	= values %$bound;
		}
		if (blessed($q)) {
			# skip results when we were matching over variable named graphs (GRAPH ?g {...})
			# and where the graph variable is bound to the nil node
			# (the nil node is used to represent the default graph, which should never match inside a GRAPH block).
			my $node	= $row->{ $q->name };
			if (blessed($node)) {
				next if ($node->isa('RDF::Trine::Node::Nil'));
			}
		}
		my $result	= RDF::Query::VariableBindings->new( $row );
		if (my $d = $self->delegate) {
			$d->log_result( $self, $result );
		}
		return $result;
	}
	return;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open BGP";
	}
	
	delete $self->[0]{iter};
	$self->SUPER::close();
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
	return 'bgp';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(*T);
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
