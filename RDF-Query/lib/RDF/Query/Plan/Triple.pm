# RDF::Query::Plan::Triple
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Triple - Executable query plan for Triples.

=head1 VERSION

This document describes RDF::Query::Plan::Triple version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Triple;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( @triple ) >>

=cut

sub new {
	my $class	= shift;
	my @triple	= splice(@_, 0, 3);
	my $keys	= shift || {};
	my $self	= $class->SUPER::new( @triple );
	$self->[0]{logging_keys}	= $keys;
	
	### the next two loops look for repeated variables because some backends
	### can't distinguish a pattern like { ?a ?a ?b }
	### from { ?a ?b ?c }. if we find repeated variables (there can be at most
	### one since there are only three nodes in a triple), we save the positions
	### in the triple that hold the variable, and the code in next() will filter
	### out any results that don't have the same value in those positions.
	###
	### in the first pass, we also set up the mapping that will let us pull out
	### values from the result triples to construct result bindings.
	
	my %var_to_position;
	my @methodmap	= qw(subject predicate object);
	my %counts;
	my $dup_var;
	foreach my $idx (0 .. 2) {
		my $node	= $triple[ $idx ];
		if (blessed($node) and $node->isa('RDF::Trine::Node::Variable')) {
			my $name	= $node->name;
			$var_to_position{ $name }	= $methodmap[ $idx ];
			$counts{ $name }++;
			if ($counts{ $name } >= 2) {
				$dup_var	= $name;
			}
		}
	}
	$self->[0]{referenced_variables}	= [ keys %counts ];
	
	my @positions;
	if (defined($dup_var)) {
		foreach my $idx (0 .. 2) {
			my $var	= $triple[ $idx ];
			if (blessed($var) and $var->isa('RDF::Trine::Node::Variable')) {
				my $name	= $var->name;
				if ($name eq $dup_var) {
					push(@positions, $methodmap[ $idx ]);
				}
			}
		}
	}
	
	$self->[0]{mappings}	= \%var_to_position;
	
	if (@positions) {
		$self->[0]{dups}	= \@positions;
	}
	
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "TRIPLE plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	$l->trace( "executing RDF::Query::Plan::Triple" );
	
	$self->[0]{start_time}	= [gettimeofday];
	my @triple	= @{ $self }[ 1,2,3 ];
	my $bound	= $context->bound;
	if (%$bound) {
		foreach my $i (0 .. $#triple) {
			next unless ($triple[$i]->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $triple[$i]->name }));
			$triple[ $i ]	= $bound->{ $triple[$i]->name };
		}
	}

	$l->trace( "- triple with bound values is " . join(', ', map { blessed($_) ? $_->sse : '_' } @triple) );
	my $nil		= RDF::Trine::Node::Nil->new();	# if we want the default graph to be a union of the named graphs, this should be undef instead
	my $iter	= $context->model->get_statements( @triple[0..2], $nil );
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->[0]{bound}	= $bound;
		$self->[0]{logger}	= $context->logger;
		$self->[0]{count}	= 0;
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open TRIPLE";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	my $iter	= $self->[0]{iter};
	LOOP: while (my $row = $iter->next) {
		if ($l->is_trace) {
			$l->trace( "- got triple from model: " . $row->as_string );
		}
		if (my $pos = $self->[0]{dups}) {
			$l->trace( "- checking for duplicate variables in triple" );
			my @pos	= @$pos;
			my $first_method	= shift(@pos);
			my $first			= $row->$first_method();
			foreach my $p (@pos) {
				unless ($first->equal( $row->$p() )) {
					next LOOP;
				}
			}
		}
		
		my $binding	= {};
		
		foreach my $key (keys %{ $self->[0]{mappings} }) {
			my $method	= $self->[0]{mappings}{ $key };
			$binding->{ $key }	= $row->$method();
		}
		my $pre_bound	= $self->[0]{bound};
		my $bindings	= RDF::Query::VariableBindings->new( $binding );
		if ($row->can('label')) {
			if (my $o = $row->label('origin')) {
				$bindings->label( origin => [ $o ] );
			}
		}
		@{ $bindings }{ keys %$pre_bound }	= values %$pre_bound;
		$self->[0]{count}++;
		if (my $d = $self->delegate) {
			$d->log_result( $self, $bindings );
		}
		return $bindings;
	}
	return;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open TRIPLE";
	}
	
# 	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	my $t0		= delete $self->[0]{start_time};
	my $count	= delete $self->[0]{count};
	if (my $log = delete $self->[0]{logger}) {
# 		$l->debug("logging triple execution statistics");
		my $elapsed = tv_interval ( $t0 );
		if (my $sparql = $self->logging_keys->{sparql}) {
# 			$l->debug("- SPARQL: $sparql");
			$log->push_key_value( 'execute_time-triple', $sparql, $elapsed );
			$log->push_key_value( 'cardinality-triple', $sparql, $count );
# 			$l->debug("- elapsed: $elapsed");
# 			$l->debug("- count: $count");
		}
		if (my $bf = $self->logging_keys->{bf}) {
# 			$l->debug("- cardinality-bf-triple: $bf: $count");
			$log->push_key_value( 'cardinality-bf-triple', $bf, $count );
		}
	}
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< nodes >>

Returns a list of the three node objects that comprise the triple pattern this plan will return.

=cut

sub nodes {
	my $self	= shift;
	return @{ $self }[1,2,3];
}

=item C<< triple >>

Returns a RDF::Trine::Statement object representing the triple pattern this plan will return.

=cut

sub triple {
	my $self	= shift;
	my @nodes	= $self->nodes;
	return RDF::Trine::Statement->new( @nodes );
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $context	= shift;
	my $bf		= '';
	my $bound	= $context->bound;
	foreach my $n (@{ $self }[1,2,3]) {
		if ($n->isa('RDF::Trine::Node::Variable')) {
			if (my $b = $bound->{ $n->name }) {
				$bf	.= 'b';
			} else {
				$bf	.= 'f';
			}
		} else {
			$bf	.= 'b';
		}
	}
	return $bf;
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
	return 'triple';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(N N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->nodes);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	$g->add_node( "$self", label => "Triple" . $self->graph_labels );
	my @names	= qw(subject predicate object);
	foreach my $i (0 .. 2) {
		my $n	= $self->[ $i + 1 ];
		my $rel	= $names[ $i ];
		my $str	= $n->sse( {}, '' );
		$g->add_node( "${self}$n", label => $str );
		$g->add_edge( "$self" => "${self}$n", label => $names[ $i ] );
	} 
	return "$self";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
