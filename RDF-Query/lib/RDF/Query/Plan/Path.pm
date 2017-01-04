# RDF::Query::Plan::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Path - Executable query plan for Paths.

=head1 VERSION

This document describes RDF::Query::Plan::Path version 2.918.

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
use Scalar::Util qw(blessed refaddr);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=item C<< new ( $path_operator, $path, $start, $end, $graph, $distinct, %args ) >>

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	my $graph	= shift;
	my $distinct	= shift;
	my %args	= @_;
	my $self	= $class->SUPER::new( $op, $path, $start, $end, $graph, $distinct, \%args );
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
	$self->[0]{delegate}	= $context->delegate;
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
	
	$self->[0]{bound}	= $bound;
	$self->[0]{graph}	= $graph;
	$self->[0]{count}	= 0;
	$self->[0]{context}	= $context;
	$self->state( $self->OPEN );

	my $op			= $self->path_operator;
	if ($op eq 'NegatedPropertySet') {
		$self->_run_nps();
	} elsif ($op eq 'ZeroOrMorePath') {
		$self->_run_zeroormore();
	} elsif ($op eq 'OneOrMorePath') {
		$self->_run_oneormore();
	} elsif ($op eq 'ZeroLengthPath') {
		$self->_run_zerolength();
	}
	
	$self;
}


sub _run_nps {
	my $self	= shift;
	my $context	= $self->[0]{context};
	my $graph	= $self->[0]{graph};
	$graph		= RDF::Trine::Node::Nil->new() unless (defined($graph));
	my $model	= $context->model;
	my $path	= $self->path;
	
	my $var		= RDF::Query::Node::Variable->new();
	my $st		= RDF::Query::Algebra::Quad->new( $self->start, $var, $self->end, $graph );
	my @nodes	= $st->nodes;
	my $plan    = RDF::Query::Plan::Quad->new( @nodes[0..2], $graph );
	my %not;
	foreach my $n (@$path) {
		$not{ $n->uri_value }++;
	}
	
	$plan->execute( $context );
	while (my $row = $plan->next) {
		if (my $p = $row->{ $var->name }) {
			next if (exists $not{ $p->uri_value });
		}
		push(@{ $self->[0]{results} }, $row);
	}
}

sub _run_zeroormore {
	my $self	= shift;
	my $context	= $self->[0]{context};
	my $graph	= $self->[0]{graph};
	$graph		= RDF::Trine::Node::Nil->new() unless (defined($graph));
	my $model	= $context->model;
	my $path	= $self->path;
	my @vars		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Variable') } ($self->start, $self->end);
	if (scalar(@vars) == 2) {
		# var path+ var
		my %nodes;
		foreach my $n ($model->subjects(undef, undef, $graph), $model->objects(undef, undef, $graph)) {
			$nodes{ $n->as_string } = $n;
		}
		my $end		= $self->end;
		my $path	= $self->path;
		my @names	= map { $_->name } @vars;
		foreach my $start (values %nodes) {
# 			warn "starting var path* var path at $start";
			my $r	= [];
			$self->_alp( $start, $path, $r, {} );
			foreach my $term (@$r) {
				my %data	= ($names[0] => $start, $names[1] => $term);
				my $vb          = RDF::Query::VariableBindings->new(\%data);
				push(@{ $self->[0]{results} }, $vb);
			}
		}
	} elsif (scalar(@vars) == 1) {
		my $start	= $self->start;
		my $end		= $self->end;
		my $path	= $self->path;
		if ($start->isa('RDF::Trine::Node::Variable')) {
			# var path+ term
			($start, $end)	= ($end, $start);
			$path			= ['^', $path];
		}
		
		# term path+ var
		my $r	= [];
		$self->_alp( $start, $path, $r, {} );
		
		my $name	= $vars[0]->name;
		foreach my $term (@$r) {
			my $vb          = RDF::Query::VariableBindings->new({ $name => $term });
			push(@{ $self->[0]{results} }, $vb);
		}
	} else {
		# term path+ term
		my $var	= RDF::Trine::Node::Variable->new();
		my $start	= $self->start;
		my $end		= $self->end;
		my $path	= $self->path;
		my $r	= [];
		$self->_alp( $start, $path, $r, {} );
		foreach my $term (@$r) {
			if ($term->equal( $end )) {
				my $vb          = RDF::Query::VariableBindings->new({});
				push(@{ $self->[0]{results} }, $vb);
				return;
			}
		}
	}
}

sub _run_oneormore {
	my $self	= shift;
	my $context	= $self->[0]{context};
	my $graph	= $self->[0]{graph};
	$graph		= RDF::Trine::Node::Nil->new() unless (defined($graph));
	my $model	= $context->model;
	my $path	= $self->path;
	my @vars		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Variable') } ($self->start, $self->end);
	if (scalar(@vars) == 2) {
		# var path+ var
		my %nodes;
		foreach my $n ($model->subjects(undef, undef, $graph), $model->objects(undef, undef, $graph)) {
			$nodes{ $n->as_string } = $n;
		}
		my $end		= $self->end;
		my $path	= $self->path;
		my @names	= map { $_->name } @vars;
		foreach my $start (values %nodes) {
# 			warn "starting var path+ var path at $start";
			my $x	= $self->_path_eval($start, $path);
			my $r	= [];
			while (my $n = $x->next) {
				$self->_alp( $n, $path, $r, {} );
			}
			foreach my $term (@$r) {
				my %data	= ($names[0] => $start, $names[1] => $term);
				my $vb          = RDF::Query::VariableBindings->new(\%data);
				push(@{ $self->[0]{results} }, $vb);
			}
		}
	} elsif (scalar(@vars) == 1) {
		my $start	= $self->start;
		my $end		= $self->end;
		my $path	= $self->path;
		if ($start->isa('RDF::Trine::Node::Variable')) {
			# var path+ term
			($start, $end)	= ($end, $start);
			$path			= ['^', $path];
		}
		
		# term path+ var
		my $x	= $self->_path_eval($start, $path);
		my $r	= [];
		my $V	= {};
		while (my $n = $x->next) {
			$self->_alp( $n, $path, $r, $V );
		}
		
		my $name	= $vars[0]->name;
		foreach my $term (@$r) {
			my $vb          = RDF::Query::VariableBindings->new({ $name => $term });
			push(@{ $self->[0]{results} }, $vb);
		}
	} else {
		# term path+ term
		my $var	= RDF::Trine::Node::Variable->new();
		my $start	= $self->start;
		my $end		= $self->end;
		my $path	= $self->path;
		my $x		= $self->_path_eval($start, $path);
		my $V		= {};
		while (my $n = $x->next) {
			my $r	= [];
			$self->_alp( $n, $path, $r, $V );
			foreach my $term (@$r) {
				if ($term->equal( $end )) {
					my $vb          = RDF::Query::VariableBindings->new({});
					push(@{ $self->[0]{results} }, $vb);
					return;
				}
			}
		}
	}
}

# returns an iterator of terms
sub _path_eval {
	my $self	= shift;
	my $start	= shift;
	my $path	= shift;
	my $context	= $self->[0]{context};
	my $graph	= $self->[0]{graph};
	$graph		= RDF::Trine::Node::Nil->new() unless (defined($graph));
	my $var		= RDF::Query::Node::Variable->new();
	my $plan	= RDF::Query::Plan->__path_plan( $start, $path, $var, $graph, $context, prevent_distinguishing_bnodes => 1, distinct => $self->distinct );
	$plan->execute( $context );
	my $iter	= RDF::Trine::Iterator->new( sub {
		my $r	= $plan->next;
		return unless ($r);
		my $t	= $r->{ $var->name };
		return $t;
	} );
}

sub _alp {
	my $self	= shift;
	my $term	= shift;
	my $path	= shift;
	my $r		= shift;
	my $v		= shift;
	return if (exists($v->{ $term->as_string }));
	$v->{ $term->as_string }	= $term;
	push(@$r, $term);
	
	my $x	= $self->_path_eval($term, $path);
	while (my $n = $x->next) {
		$self->_alp( $n, $path, $r, $v );
	}
	
	unless ($self->distinct) {
		delete $v->{ $term->as_string };
	}
}

sub _run_zerolength {
	my $self	= shift;
	my $context	= $self->[0]{context};
	my $graph	= $self->[0]{graph};
	$graph		= RDF::Trine::Node::Nil->new() unless (defined($graph));
	my $model	= $context->model;
	my $path	= $self->path;
	my @vars		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Variable') } ($self->start, $self->end);
	if (scalar(@vars) == 2) {
		# -- bind VAR(s) to subjects and objects in the current active graph
		my @names	= map { $_->name } @vars;
		my %nodes;
		foreach my $n ($model->subjects(undef, undef, $graph), $model->objects(undef, undef, $graph)) {
			$nodes{ $n->as_string } = $n;
		}
		foreach my $n (values %nodes) {
			my %data;
			@data{ @names }	= ($n) x scalar(@names);
			my $vb			= RDF::Query::VariableBindings->new(\%data);
			push(@{ $self->[0]{results} }, $vb);
		}
	} elsif (scalar(@vars) == 1) {
		my ($term)	= grep { blessed($_) and not($_->isa('RDF::Trine::Node::Variable')) } ($self->start, $self->end);
		my $name	= $vars[0]->name;
		my $vb		= RDF::Query::VariableBindings->new({ $name => $term });
		push(@{ $self->[0]{results} }, $vb);
	} else {
		if ($self->start->equal( $self->end )) {
			my $vb          = RDF::Query::VariableBindings->new({});
			push(@{ $self->[0]{results} }, $vb);
		}
	}
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
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PATH";
	}
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< path_operator >>

Returns the path operation.

=cut

sub path_operator {
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
	my $self	= shift;
	return $self->[6];
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
	my $self	= shift;
	return $self->path_operator;
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(s N N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $path	= $self->path;
	if (blessed($path)) {
		return ($path->sse, $self->start, $self->end, $self->graph);
	} else {
		return ('(undefined path)', $self->start, $self->end, $self->graph);
	}
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
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self));
	$string		.= $self->start->explain($s, $count+1);
	my $path	= $self->path;
	if ($type eq 'NegatedPropertySet') {
		$string	.= "${indent}${s}(\n";
		foreach my $iri (@$path) {
			$string		.= "${indent}${s}${s}" . $iri->as_string . "\n";
		}
		$string	.= "${indent}${s})\n";
	} elsif ($type =~ /^ZeroOrMorePath|OneOrMorePath|ZeroLengthPath$/) {
		$string	.= "${indent}${s}${s}" . $self->_path_as_string($path) . "\n";
	} else {
		throw RDF::Query::Error;
	}
	$string		.= $self->end->explain($s, $count+1);
# 	$string		.= $self->pattern->explain( $s, $count+1 );
	return $string;
}

sub _path_as_string {
	my $self	= shift;
	my $path	= shift;
	if (blessed($path)) {
		return $path->as_string;
	}
	
	my ($op, @nodes)	= @$path;
	if ($op eq '/') {
		return join('/', map { $self->_path_as_string($_) } @nodes);
	} elsif ($op =~ /^[?+*]$/) {
		return '(' . $self->_path_as_string($nodes[0]) . ')' . $op;
	} else {
		throw RDF::Query::Error -text => "Can't serialize path '$op' in plan explanation";
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
