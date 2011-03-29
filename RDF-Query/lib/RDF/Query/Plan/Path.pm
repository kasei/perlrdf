# RDF::Query::Plan::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Path - Executable query plan for Paths.

=head1 VERSION

This document describes RDF::Query::Plan::Path version 2.905.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Path;

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
	$VERSION	= '2.905';
}

######################################################################

=item C<< new ( $op, $path, $start, $end, $graph, %args ) >>

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my $path	= shift;
	my $start	= shift;
	my $end		= shift;
	my $graph	= shift;
	my %args	= @_;
	my $self	= $class->SUPER::new( $op, $path, $start, $end, $graph, \%args );
	my %vars;
	for ($start, $end) {
		$vars{ $_->name }++ if ($_->isa('RDF::Query::Node::Variable'));
	}
	$self->[0]{referenced_variables}	= [keys %vars];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PATH plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	$l->trace( "executing RDF::Query::Plan::Path " . $self->sse );
	
	my $start	= $self->start;
	my $end		= $self->end;
	my $graph	= $self->graph;
	my $bound	= $context->bound;
	if (%$bound) {
		for ($start, $end, $graph) {
			next unless (blessed($_));
			next unless ($_->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $_->name }));
			$_	= $bound->{ $_->name };
		}
	}
	
	$self->[0]{results}	= [];
	my @vars		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Variable') } ($self->start, $self->end);
	my $model		= $context->model;
	my @node_args	= ($graph) ? (undef, undef, $graph) : (undef, undef, RDF::Trine::Node::Nil->new());

	if (not(@vars)) {
		$l->trace( '- 0-length path is bb' );
		# BOUND :p{0} BOUND
		# -- are they the same term?
		my $s	= $self->start;
		my $e	= $self->end;
		if ($s->equal($e)) {
			my $vb		= RDF::Query::VariableBindings->new({});
			push(@{ $self->[0]{results} }, $vb);
		}
		$self->[1]	= 'noop';	# update the op to noop
	}
	
	if ($self->op eq '0') {
		if (scalar(@vars) == 1) {
			$l->trace( '- 0-length path is bf' );
			# BOUND :p{0} VAR
			# VAR :p{0} BOUND
			# -- provide one result with VAR -> term
			my ($term)	= grep { blessed($_) and not($_->isa('RDF::Trine::Node::Variable')) } ($self->start, $self->end);
			my $name	= $vars[0]->name;
			my $vb		= RDF::Query::VariableBindings->new({ $name => $term });
			push(@{ $self->[0]{results} }, $vb);
		} else {
			$l->trace( '- 0-length path is ff' );
			# VAR :p{0} VAR
			# VAR1 :p{0} VAR2
			# -- bind VAR(s) to subjects and objects in the current active graph
			my @names	= map { $_->name } @vars;
			my %nodes;
			foreach my $n ($model->subjects(@node_args), $model->objects(@node_args)) {
				$nodes{ $n->as_string }	= $n;
			}
			foreach my $n (values %nodes) {
				my %data;
				@data{ @names }	= ($n) x scalar(@names);
				my $vb		= RDF::Query::VariableBindings->new(\%data);
# 				foreach my $name (@names) {
# 					$vb->{ $name }	= $n;
# 				}
				push(@{ $self->[0]{results} }, $vb);
			}
		}
	} elsif ($self->op eq '*') {
		if (scalar(@vars) == 1) {
			$l->trace( '- ZeroOrMore path is bf' );
			my ($term)	= grep { blessed($_) and not($_->isa('RDF::Trine::Node::Variable')) } ($self->start, $self->end);
			my $fwd		= (blessed($self->start) and not($self->start->isa('RDF::Trine::Node::Variable')));
			my $partial_result	= RDF::Query::VariableBindings->new();
			unless ($fwd) {
				@{ $self }[3,4]	= @{ $self }[4,3];	# swap start and end nodes
			}
			
			push(@{ $self->[0]{alp_state} },  [ $term, $self->path, {}, $partial_result, $self->end->name ]);
		} else {
			$l->trace( '- ZeroOrMore path is ff' );
			my $var	= $self->start->name;
			my %nodes;
			foreach my $n ($model->subjects(@node_args), $model->objects(@node_args)) {
				$nodes{ $n->as_string }	= $n;
			}
			foreach my $term (values %nodes) {
				my $partial_result	= RDF::Query::VariableBindings->new( { $var => $term } );
				push(@{ $self->[0]{alp_state} },  [ $term, $self->path, {}, $partial_result, $self->end->name ]);
			}
		}
	} elsif ($self->op eq '+') {
		if (scalar(@vars) == 1) {
			$l->trace( '- OneOrMore path is bf' );
			my ($term)	= grep { blessed($_) and not($_->isa('RDF::Trine::Node::Variable')) } ($self->start, $self->end);
			my $fwd		= (blessed($self->start) and not($self->start->isa('RDF::Trine::Node::Variable')));
			unless ($fwd) {
				@{ $self }[3,4]	= @{ $self }[4,3];	# swap start and end nodes
			}
			
			my $plan	= RDF::Query::Plan->__path_plan( $self->start, $self->path, $self->end, $self->graph, $context, %{ $self->[6] } );
			$plan->execute( $context );
			while (my $row = $plan->next) {
				$l->trace("got ALP path row: $row");
				my $term	= ($self->end->isa('RDF::Query::Node::Variable')) ? $row->{ $self->end->name } : $self->end;
				my $partial_result	= RDF::Query::VariableBindings->new( {} );
				push(@{ $self->[0]{alp_state} },  [ $term, $self->path, {}, $partial_result, $self->end->name ]);
			}
		} else {
			$l->trace( '- OneOrMore path is ff' );
			my $var	= $self->start->name;
			my %nodes;
			foreach my $n ($model->subjects(@node_args), $model->objects(@node_args)) {
				$nodes{ $n->as_string }	= $n;
			}
			foreach my $term (values %nodes) {
				my $plan	= RDF::Query::Plan->__path_plan( $self->start, $self->path, $self->end, $self->graph, $context, %{ $self->[6] } );
				$plan->execute( $context );
				while (my $row = $plan->next) {
					$l->trace("got ALP path row: $row");
					my $partial_result	= RDF::Query::VariableBindings->new( { $var => $term } );
					my $term2	= ($self->end->isa('RDF::Query::Node::Variable')) ? $row->{ $self->end->name } : $self->end;
					push(@{ $self->[0]{alp_state} },  [ $term2, $self->path, {}, $partial_result, $self->end->name ]);
				}
			}
		}
	}
	
	$self->[0]{end}		= $end;
	$self->[0]{start}	= $start;
	$self->[0]{graph}	= $graph;
	$self->[0]{paths}	= [[]];
	$self->[0]{bound}	= $bound;
	$self->[0]{count}	= 0;
	$self->[0]{context}	= $context;
	$self->state( $self->OPEN );
	
	$self;
}


# start this off by making sure $self->[0]{alp_state}[0]	= [ $term, $path, \%seen, $vb_result, $path_end_variable_name ]
sub _alp {
	my $self	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	my $data	= shift(@{ $self->[0]{alp_state} });
	my ($term, $path, $seen, $vb, $var)	= @$data;
	$l->trace('ALP executing with term ' . $term->as_string);
	my %seen	= %$seen;
# 	use Data::Dumper;
# 	warn "ALP seen: " . Dumper(\%seen);
	return if ($seen{ $term->as_string });
	$seen{ $term->as_string }++;
	my $result	= RDF::Query::VariableBindings->new( $vb );
	$result->{ $var }	= $term;
	push( @{ $self->[0]{alp_results} }, $result );
	my $plan	= RDF::Query::Plan->__path_plan( $term, $path, $self->end, $self->graph, $self->[0]{context}, %{ $self->[6] } );
	$plan->execute( $self->[0]{context} );
	while (my $row = $plan->next) {
		$l->trace("got ALP path row: $row");
		my $s	= ($self->start->isa('RDF::Query::Node::Variable')) ? $row->{ $self->start->name } : $self->start;
		my $e	= ($self->end->isa('RDF::Query::Node::Variable')) ? $row->{ $self->end->name } : $self->end;
		push( @{ $self->[0]{alp_state} }, [ $e, $path, \%seen, $vb, $var ] );
	}
}

sub _alp_result {
	my $self	= shift;
	return unless (scalar(@{ $self->[0]{alp_results} }));
	my $vb		= shift @{ $self->[0]{alp_results} };
# 	if ($vb) {
# 		warn "Returning ALP result: " . Dumper($r);
# 	}
	return $vb;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PATH";
	}
	
	if (scalar(@{ $self->[0]{results} })) {
		my $result	= shift(@{ $self->[0]{results} });
		$l->trace( 'returning path result: ' . $result ) if (defined($result));
		return $result;
	}
	
	my $op		= $self->op;
	if ($op eq 'noop') {
		# noop
	} elsif ($op eq '0') {
		if (scalar(@{ $self->[0]{results} })) {
			my $result	= shift(@{ $self->[0]{results} });
			$l->trace( 'returning path result: ' . $result ) if (defined($result));
			return $result;
		}
	} elsif ($op eq '*') {
		while (scalar(@{ $self->[0]{alp_state} })) {
			$self->_alp;
			if (my $r = $self->_alp_result) {
				return $r;
			}
		}
		my $r	= $self->_alp_result;
		return $r;
	} elsif ($op eq '+') {
		while (scalar(@{ $self->[0]{alp_state} })) {
			$self->_alp;
			if (my $r = $self->_alp_result) {
				return $r;
			}
		}
		my $r	= $self->_alp_result;
		return $r;
	}

	my $result	= shift(@{ $self->[0]{results} });
	$l->trace( 'returning path result: ' . $result ) if (defined($result));
	return $result;
}

sub _add_bindings {
	my $self		= shift;
	my $bindings	= shift;
	my %bindings	= map { $_ => $bindings->{ $_ } } @{ $self->[0]{referenced_variables} };
	my $pre_bound	= $self->[0]{bound};
	@bindings{ keys %$pre_bound }	= values %$pre_bound;
	return RDF::Query::VariableBindings->new( \%bindings );
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PATH";
	}
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< op >>

Returns the path operation.

=cut

sub op {
	my $self	= shift;
	return $self->[1];
}

=item C<< path >>

Returns the path expression.

=cut

sub path {
	my $self	= shift;
	return $self->[2];
}

=item C<< start >>

Returns the path start node.

=cut

sub start {
	my $self	= shift;
	return $self->[3];
}

=item C<< end >>

Returns the path end node.

=cut

sub end {
	my $self	= shift;
	return $self->[4];
}

=item C<< graph >>

Returns the named graph.

=cut

sub graph {
	my $self	= shift;
	return $self->[5];
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
	return 'path';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(s s N N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $path	= $self->path;
	if (blessed($path)) {
		return ($self->op, $path->sse, $self->start, $self->end, $self->graph);
	} else {
		return ($self->op, '*PATH*', $self->start, $self->end, $self->graph);
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
