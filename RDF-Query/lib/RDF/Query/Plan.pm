# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

=head1 VERSION

This document describes RDF::Query::Plan version 2.918.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);
use Scalar::Util qw(blessed reftype refaddr);
use RDF::Query::Error qw(:try);
use RDF::Query::BGPOptimizer;

use RDF::Query::Plan::Aggregate;
use RDF::Query::Plan::BasicGraphPattern;
use RDF::Query::Plan::Constant;
use RDF::Query::Plan::Construct;
use RDF::Query::Plan::Distinct;
use RDF::Query::Plan::Filter;
use RDF::Query::Plan::Join::NestedLoop;
use RDF::Query::Plan::Join::PushDownNestedLoop;
use RDF::Query::Plan::Limit;
use RDF::Query::Plan::Offset;
use RDF::Query::Plan::Project;
use RDF::Query::Plan::Extend;
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Service;
use RDF::Query::Plan::Sort;
use RDF::Query::Plan::ComputedStatement;
use RDF::Query::Plan::ThresholdUnion;
use RDF::Query::Plan::Union;
use RDF::Query::Plan::SubSelect;
use RDF::Query::Plan::Iterator;
use RDF::Query::Plan::Load;
use RDF::Query::Plan::Clear;
use RDF::Query::Plan::Update;
use RDF::Query::Plan::Minus;
use RDF::Query::Plan::Sequence;
use RDF::Query::Plan::Path;
use RDF::Query::Plan::NamedGraph;
use RDF::Query::Plan::Copy;
use RDF::Query::Plan::Move;

use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

######################################################################

our ($VERSION, %PLAN_CLASSES);
BEGIN {
	$VERSION		= '2.918';
	%PLAN_CLASSES	= (
		service	=> 'RDF::Query::Plan::Service',
	);
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my @args	= @_;
	return bless( [ { __state => $class->READY }, @args ], $class );
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($);

=item C<< next >>

=cut

sub next;

=item C<< get_all >>

Returns all remaining rows.

=cut

sub get_all {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "get_all can't be called on an unopen plan";
	}
	my @rows;
	while (my $row = $self->next) {
		push(@rows, $row);
	}
	return @rows;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	$self->state( CLOSED );
}

=item C<< state ( [ $state ] ) >>

Returns the current state of the plan (either READY, OPEN, or CLOSED).
If C<< $state >> is provided, updates the plan to a new state.

=cut

sub state {
	my $self	= shift;
	if (scalar(@_)) {
		$self->[0]{__state}	= shift;
	}
	return $self->[0]{__state};
}

=item C<< logging_keys >>

=cut

sub logging_keys {
	my $self	= shift;
	return $self->[0]{logging_keys} || {};
}

=item C<< explain >>

Returns a string serialization of the query plan appropriate for display
on the command line.

=cut

sub explain {
	my $self	= shift;
# 	warn 'Explaining query plan: ' . $self->serialize();
	my ($s, $count)	= ('  ', 0);
	if (@_) {
		$s		= shift;
		$count	= shift;
	}
	my $indent	= '' . ($s x $count);
	my $type	= $self->plan_node_name;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self));
	foreach my $p ($self->plan_node_data) {
		if (blessed($p)) {
			if ($p->isa('RDF::Trine::Statement::Quad')) {
				$string	.= "${indent}${s}" . join(' ', map { ($_->isa('RDF::Trine::Node::Nil')) ? "(nil)" : $_->as_sparql } $p->nodes) . "\n";
			} elsif ($p->isa('RDF::Trine::Node::Nil')) {
				$string	.= "${indent}${s}(nil)\n";
			} else {
				$string	.= $p->explain( $s, $count+1 );
			}
		} elsif (ref($p)) {
			$string	.= "${indent}${s}" . Dumper($p);
			Carp::cluck 'unexpected non-blessed ref in RDF::Query::Plan->explain: ' . Dumper($p);
		} else {
			no warnings 'uninitialized';
			$string	.= "${indent}${s}$p\n";
		}
	}
	return $string;
}

=item C<< sse >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift || '';
	my $more	= '    ';
	my @proto	= $self->plan_prototype;
	my @data	= $self->plan_node_data;
	my $name	= $self->plan_node_name;
	
	my @args;
	my $list	= \@data;
	foreach my $i (0 .. $#proto) {
		my $p	= $proto[ $i ];
		push(@args, $self->_sse( $context, $indent, $more, $p, $list ));
	}
	return "(${name} " . join(' ', map { defined($_) ? $_ : '()' } @args) . ")";
}

sub _sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= shift;
	my $p		= shift;
	my $list	= shift;
	if ($p =~ m/^[PQTNWEJVqibswu]$/) {
		my $v	= shift(@$list);
		return $self->_sse_atom($context, $indent, $more, $p, $v);
	} elsif ($p eq 'A') {
		my $v	= shift(@$list);
		if (blessed($v)) {
			return $v->sse( $context, $indent );
		} else {
			return '()';
		}
	} elsif (substr($p, 0, 1) eq '\\') {
		my $rest	= substr($p, 1);
		my $v		= shift(@$list);
		my @args;
		while (@$v) {
			push(@args, $self->_sse( $context, $indent, $more, $rest, $v ));
		}
		return '(' . join(' ', @args) . ')';
	} elsif (substr($p, 0, 1) eq '*') {
		my $rest	= substr($p, 1);
		my @args;
		while (@$list) {
			push(@args, $self->_sse( $context, $indent, $more, $rest, $list ));
		}
		no warnings 'uninitialized';
		return join("\n${indent}${more}", '', @args);
	} elsif ($p =~ m/^[PQTNWEJVqibswu\\*]{2,}$/) {
		my @args;
		foreach my $p2 (split(//, $p)) {
			my $v	= shift(@$list);
			push(@args, $self->_sse($context, $indent, $more, $p2, [$v]));
		}
		return '(' . join(' ', @args) . ')';
	} else {
		Carp::confess "unrecognized plan node prototype '$p'";
	}
}

sub _sse_atom {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	my $more	= shift;
	my $p		= shift;
	my $v		= shift;
	no warnings 'uninitialized';
	
	my $ns		= $context->{ namespaces } || {};
	my %ns		= %$ns;
	
	if ($p eq 's') {
		for ($v) {
			s/\\/\\\\/g;
			s/"/\\"/g;
			s/\n/\\n/g;
			s/\t/\\t/g;
		}
		return qq["$v"];
	} elsif ($p eq 'w') {
		return $v;
	} elsif ($p eq 'u') {
		return qq[<$v>];
	} elsif ($p eq 'i') {
		return $v;
	} elsif ($p eq 'b') {
		return $v;
	} elsif ($p eq 'W') {
		if (blessed($v)) {
			return $v->sse( { namespaces => \%ns }, "${indent}${more}" );
		} else {
			return $v;
		}
	} elsif ($p =~ m/^[PNETV]$/) {
		if (blessed($v)) {
		
			Carp::cluck unless ($v->can('sse'));
			return $v->sse( { namespaces => \%ns }, "${indent}${more}" );
		} else {
			return '()';
		}
	} elsif ($p eq 'J') {
		if ($v->isa('RDF::Query::Node::Variable')) {
			return $v->name;
		} else {
			return $v->sse( { namespaces => \%ns }, "${indent}${more}" );
		}
	}
}

=item C<< serialize >>

Return a serialization of the query plan.

=cut

sub serialize {
	my $self	= shift;
	
}

=item C<< delegate >>

Returns the delegate object if available.

=cut

sub delegate {
	my $self	= shift;
	return $self->[0]{delegate};
}

=item C<< referenced_variables >>

Returns a list of variable names that are referenced by this plan.

=cut

sub referenced_variables {
	my $self	= shift;
	my $refs	= $self->[0]{referenced_variables};
	return @{ $refs };
}

=item C<< as_iterator ( $context ) >>

Returns an RDF::Trine::Iterator object for the current (already executed) plan.

=cut

sub as_iterator {
	my $self	= shift;
	my $context	= shift;
	my $vars	= $context->requested_variables;
	my $stream	= RDF::Trine::Iterator::Bindings->new( sub { $self->next }, $vars, distinct => $self->distinct, sorted_by => $self->ordered );
	return $stream;
}

=item C<< is_update >>

Returns true if the plan represents an update operation.

=cut

sub is_update {
	return 0;
}

=item C<< label ( $label => $value ) >>

Sets the named C<< $label >> to C<< $value >> for this plan object.
If no C<< $value >> is given, returns the current label value, or undef if none
exists.

=cut

sub label {
	my $self	= shift;
	my $label	= shift;
	if (@_) {
		my $value	= shift;
		$self->[0]{labels}{ $label }	= $value;
	}
	return $self->[0]{labels}{ $label };
}

=item C<< graph_labels >>

=cut

sub graph_labels {
	my $self	= shift;
	my @labels;
	foreach my $k (keys %{ $self->[0]{labels} || {} }) {
		next if ($k eq 'algebra');
		my $v	= $self->label( $k );
		local($Data::Dumper::Indent)	= 0;
		my $l	= Data::Dumper->Dump([$v], [$k]);
		push(@labels, $l);
	}
	my $label	= join(", ", @labels);
	return ' ' . $label;
}

sub DESTROY {
	my $self	= shift;
	if ($self->state == OPEN) {
		$self->close;
	}
}

################################################################################

=item C<< generate_plans ( $algebra, $execution_context, %args ) >>

Returns a list of equivalent query plan objects for the given algebra object.

=cut

sub generate_plans {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my $algebra	= shift;
	my $context	= shift;
	my $config	= $context->options || {};
	
	my %args	= @_;
	my $active_graph	= $args{ active_graph } || RDF::Trine::Node::Nil->new();
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan");
	unless (blessed($algebra) and $algebra->isa('RDF::Query::Algebra')) {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan with a non-algebra object $algebra");
	}
	
	$l->trace("generating query plan for " . $algebra->sse({ indent => '  ' }, ''));
	
	############################################################################
	### Optimize simple COUNT(*) aggregates over BGPs
	if ($algebra->isa('RDF::Query::Algebra::Extend')) {
		my $agg	= $algebra->pattern;
		if ($agg->isa('RDF::Query::Algebra::Aggregate')) {
			my @group	= $agg->groupby;
			if (scalar(@group) == 0) {
				my @ops		= $agg->ops;
				if (scalar(@ops) == 1 and $ops[0][0] eq 'COUNT(*)') {
					my $ggp	= $agg->pattern;
					if ($ggp->isa('RDF::Query::Algebra::GroupGraphPattern')) {
						my @bgp	= $ggp->patterns;
						if (scalar(@bgp) == 1 and ($bgp[0]->isa('RDF::Query::Algebra::BasicGraphPattern'))) {
							my $bgp	= $bgp[0];
							my @triples	= $bgp->triples;
							if (scalar(@triples) == 1) {
								$l->debug("Optimizing for COUNT(*) on 1-triple BGP: " . $bgp->sse({ indent => '  ' }, ''));
								my $vars	= $algebra->vars;
								my $alias	= $vars->[0];
								my $name	= $alias->name;
								my $done	= 0;
								my $model	= $context->model;
								my $code	= sub {
									return if ($done);
									$done	= 1;
									#warn Dumper(\@triples); # XXX
									my $count	= $model->count_statements( $triples[0]->nodes );
									my $lit		= RDF::Query::Node::Literal->new($count, undef, 'http://www.w3.org/2001/XMLSchema#integer');
									my $vb	= RDF::Query::VariableBindings->new( {
										$name 		=> $lit,
										'COUNT(*)'	=> $lit,	# this has to be kept around in case a HAVING clause needs it without the alias $name
									} );
								};
								my $iter	= RDF::Trine::Iterator::Bindings->new( $code, [] );
								return RDF::Query::Plan::Iterator->new( $iter );
							}
						}
					}
				}
			}
		}
	}
	############################################################################
	
	my ($project);
	my $constant	= delete $args{ constants };
	
	if ($algebra->isa('RDF::Query::Algebra::Sort') or not($algebra->is_solution_modifier)) {
		# projection has to happen *after* sorting, since a sort expr might reference a variable that we project away
		$project	= delete $args{ project };
	}
	
	my @return_plans;
	my $aclass	= ref($algebra);
	my ($type)	= ($aclass =~ m<::(\w+)$>);
	if ($type eq 'Aggregate') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @groups	= $algebra->groupby;
		my @ops;
		foreach my $o ($algebra->ops) {
			my ($alias, $op, $opts, @cols)	= @$o;
			push(@ops, [ $alias, $op, $opts, @cols ]);
		}
		my @plans	= map { RDF::Query::Plan::Aggregate->new( $_, \@groups, expressions => \@ops ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Construct') {
		my $triples	= $algebra->triples;
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Construct->new( $_, $triples ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Distinct') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Distinct->new( $_ ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Filter') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args, active_graph => $active_graph );
		my $expr	= $algebra->expr;
		my @plans	= map { RDF::Query::Plan::Filter->new( $expr, $_, $active_graph ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'BasicGraphPattern') {
		my @triples	= map {
			($args{ prevent_distinguishing_bnodes })
				? $_
				: $_->distinguish_bnode_variables
		} $algebra->triples;
		my @normal_triples;
		my @csg_triples;
		foreach my $t (@triples) {
			if (my @csg_plans = $self->_csg_plans( $context, $t )) {
				push(@csg_triples, $t);
			} else {
				my @nodes	= $t->nodes;
				$t	= RDF::Query::Algebra::Quad->new( @nodes[ 0..2 ], $active_graph );
# 				if (my $g = $args{ named_graph }) {
# 					my @nodes	= $t->nodes;
# 					$t	= RDF::Query::Algebra::Quad->new( @nodes[0..2], $g );
# 				}
				push(@normal_triples, $t);
			}
		}
		
		my @plans;
		if (scalar(@normal_triples) == 0) {
			my $v		= RDF::Query::VariableBindings->new( {} );
			my $plan	= RDF::Query::Plan::Constant->new( $v );
			push(@plans, $plan);
		} elsif (scalar(@normal_triples) == 1) {
			push(@plans, $self->generate_plans( @normal_triples, $context, %args ));
		} else {
			my $plan	= RDF::Query::Plan::BasicGraphPattern->new( @normal_triples );
			push(@plans, $plan);
		}
		
		if (@csg_triples) {
			my @csg_plans;
			foreach my $t (@csg_triples) {
				push(@csg_plans, [ $self->generate_plans( $t, $context, %args ) ]);
			}
			my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
			while (my $cps = shift(@csg_plans)) {
				my @temp_plans	= @plans;
				@plans			= ();
				foreach my $p (@temp_plans) {
					foreach my $cp (@$cps) {
						foreach my $join_type (@join_types) {
							my $plan	= $join_type->new( $p, $cp, 0, {} );
							push(@plans, $plan);
						}
					}
				}
			}
			push(@return_plans, @plans);
		} else {
			push(@return_plans, @plans);
		}
		
	} elsif ($type eq 'GroupGraphPattern') {
		my @input	= $algebra->patterns();
		my @patterns;
		while (my $a = shift(@input)) {
			if ($a->isa('RDF::Query::Algebra::Service')) {
				if (scalar(@input) and $input[0]->isa('RDF::Query::Algebra::Service') and $a->endpoint->value eq $input[0]->endpoint->value) {
					my $b	= shift(@input);
					if ($a->silent == $b->silent) {
						my $p	= RDF::Query::Algebra::GroupGraphPattern->new( map { $_->pattern } ($a, $b) );
						my $s	= RDF::Query::Algebra::Service->new( $a->endpoint, $p, $a->silent );
						push(@patterns, $s);
						next;
					}
				}
			}
			push(@patterns, $a);
		}
		
		my @plans;
		if (scalar(@patterns) == 0) {
			my $v		= RDF::Query::VariableBindings->new( {} );
			my $plan	= RDF::Query::Plan::Constant->new( $v );
			push(@plans, $plan);
		} elsif (scalar(@patterns) == 1) {
			push(@plans, $self->generate_plans( @patterns, $context, %args ));
		} else {
			push(@plans, map { $_->[0] } $self->_join_plans( $context, \@patterns, %args, method => 'patterns' ));
		}
		
		push(@return_plans, @plans);
	} elsif ($type eq 'Limit') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Limit->new( $algebra->limit, $_ ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'NamedGraph') {
		my @plans;
		if ($algebra->graph->isa('RDF::Query::Node::Resource')) {
			@plans	= $self->generate_plans( $algebra->pattern, $context, %args, active_graph => $algebra->graph );
		} else {
			@plans	= map { RDF::Query::Plan::NamedGraph->new( $algebra->graph, $_ ) } $self->generate_plans( $algebra->pattern, $context, %args, active_graph => $algebra->graph );
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'Offset') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Offset->new( $algebra->offset, $_ ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Optional') {
		# just like a BGP or GGP, but we have to pass the optional flag to the join constructor
		my @patterns	= ($algebra->pattern, $algebra->optional);
		my @base_plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } @patterns;
		my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
		# XXX this is currently only considering left-deep trees. maybe it should produce all trees?
		my @plans;
		my $base_a	= shift(@base_plans);
		my $base_b	= shift(@base_plans);
		foreach my $i (0 .. $#{ $base_a }) {
			foreach my $j (0 .. $#{ $base_b }) {
				my $a	= $base_a->[ $i ];
				my $b	= $base_b->[ $j ];
				foreach my $join_type (@join_types) {
					try {
						my $plan	= $join_type->new( $a, $b, 1, {} );
						push( @plans, $plan );
					} catch RDF::Query::Error::MethodInvocationError with {
# 						my $e	= shift;
# 						warn "caught MethodInvocationError: " . Dumper($e);
					};
				}
			}
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'Minus') {
		my @patterns	= ($algebra->pattern, $algebra->minus);
		my @base_plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } @patterns;
		my @plans;
		my $base_a	= shift(@base_plans);
		my $base_b	= shift(@base_plans);
		foreach my $i (0 .. $#{ $base_a }) {
			foreach my $j (0 .. $#{ $base_b }) {
				my $a	= $base_a->[ $i ];
				my $b	= $base_b->[ $j ];
				my $plan	= RDF::Query::Plan::Minus->new( $a, $b );
				push( @plans, $plan );
			}
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'Project') {
		my $pattern	= $algebra->pattern;
		my $vars	= $algebra->vars;
		my @base	= $self->generate_plans( $pattern, $context, %args );
		
		if ($constant) {
			# if there's constant data to be joined, we better do it now in case
			# the project gets rid of variables needed for the join
			my @plans	= splice( @base );
			@base		= $self->_add_constant_join( $context, $constant, @plans );
			$constant	= undef;
		}
		
		my @plans;
		foreach my $plan (@base) {
			push(@return_plans, RDF::Query::Plan::Project->new( $plan, $vars ));
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'Extend') {
		my $pattern	= $algebra->pattern;
		my $vars	= $algebra->vars;
		my @base	= $self->generate_plans( $pattern, $context, %args );
		my @plans;
		foreach my $plan (@base) {
			push(@plans, RDF::Query::Plan::Extend->new( $plan, $vars ));
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'Service') {
		my $pattern	= $algebra->pattern;
		my @base	= $self->generate_plans( $pattern, $context, %args );
		my @plans;
		foreach my $plan (@base) {
			my $sparqlcb	= sub {
				my $row		= shift;
				my $p		= $pattern;
				if ($row) {
					$p		= $p->bind_variables( $row );
				}
				my $ns			= $context->ns;
				my $pstr		= $p->as_sparql({namespaces => $ns}, '');
				unless (substr($pstr, 0, 1) eq '{') {
					$pstr	= "{ $pstr }";
				}
				my $sparql		= join("\n",
									(map { sprintf("PREFIX %s: <%s>", ($_ eq '__DEFAULT__' ? '' : $_), $ns->{$_}) } (keys %$ns)),
									sprintf("SELECT * WHERE %s", $pstr)
								);
				return $sparql;
			};
			
# 			unless ($algebra->endpoint->can('uri_value')) {
# 				throw RDF::Query::Error::UnimplementedError (-text => "Support for variable-endpoint SERVICE blocks is not implemented");
# 			}
			
			if (my $ggp = $algebra->lhs) {
				my @lhs_base	= $self->generate_plans( $ggp, $context, %args );
				foreach my $lhs_plan (@lhs_base) {
					my $splan	= RDF::Query::Plan::Service->new( $algebra->endpoint, $plan, $algebra->silent, $sparqlcb, $lhs_plan );
					push(@plans, $splan);
				}
			} else {
				push(@plans, $PLAN_CLASSES{'service'}->new( $algebra->endpoint, $plan, $algebra->silent, $sparqlcb ));
			}
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'SubSelect') {
		my $query	= $algebra->query;
		my $model	= $context->model;
		my %pargs	= %args;
		my $ag		= $args{ active_graph };
		if (blessed($ag) and $ag->isa('RDF::Query::Node::Variable')) {
			my %vars	= map { $_ => 1 } $query->pattern->referenced_variables;
			if ($vars{ $ag->name }) {
				my $new_ag		= RDF::Query::Node::Variable->new();
				my ($pattern)	= $query->pattern;
				my $new_pattern	= $pattern->bind_variables( { $ag->name => $new_ag } );
				my $apattern	= RDF::Query::Algebra::Extend->new(
									$new_pattern,
									[
										RDF::Query::Expression::Alias->new( 'alias', $ag, $new_ag )
									]
								);
				$query->{parsed}{triples}	= [$apattern];
			}
			my ($plan)	= $self->generate_plans( $query->pattern, $context, %args );
			push(@return_plans, RDF::Query::Plan::SubSelect->new( $query, $plan ));
		} else {
			my ($plan)	= $query->prepare( $context->model, planner_args => \%pargs );
			push(@return_plans, RDF::Query::Plan::SubSelect->new( $query, $plan ));
		}
	} elsif ($type eq 'Sort') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @order	= $algebra->orderby;
		my @neworder;
		foreach my $o (@order) {
			my ($dirname, $expr)	= @$o;
			my $dir	= ($dirname eq 'ASC') ? 0 : 1;
			push(@neworder, [$expr, $dir]);
		}
		my @plans	= map { RDF::Query::Plan::Sort->new( $_, @neworder ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Triple' or $type eq 'Quad') {
		my $st;
		if ($args{ prevent_distinguishing_bnodes }) {
			$st	= $algebra;
		} else {
			$st		= $algebra->distinguish_bnode_variables;
		}
		my $pred    = $st->predicate;
		my @nodes    = $st->nodes;
		
		if (my @csg_plans = $self->_csg_plans( $context, $st )) {
			push(@return_plans, @csg_plans);
		} elsif ($type eq 'Triple') {
			my $plan    = RDF::Query::Plan::Quad->new( @nodes[0..2], $active_graph, { sparql => $algebra->as_sparql, bf => $algebra->bf } );
			push(@return_plans, $plan);
		} else {
			my $plan    = (scalar(@nodes) == 4)
						? RDF::Query::Plan::Quad->new( @nodes, { sparql => $algebra->as_sparql } )
						: RDF::Query::Plan::Quad->new( @nodes, RDF::Trine::Node::Nil->new(), { sparql => $algebra->as_sparql, bf => $algebra->bf } );
			push(@return_plans, $plan);
		}
	} elsif ($type eq 'Path') {
		my @plans	= $self->_path_plans( $algebra, $context, %args );
		push(@return_plans, @plans);
	} elsif ($type eq 'Union') {
		my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->patterns;
		my $plan	= RDF::Query::Plan::Union->new( map { $_->[0] } @plans );
		push(@return_plans, $plan);
	} elsif ($type eq 'Sequence') {
		my @pat		= $algebra->patterns;
		if (@pat) {
			my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } @pat;
			my $plan	= RDF::Query::Plan::Sequence->new( map { $_->[0] } @plans );
			push(@return_plans, $plan);
		} else {
			my $stream	= RDF::Trine::Iterator::Bindings->new( sub {} );
			push(@return_plans, $stream);
		}
	} elsif ($type eq 'Load') {
		push(@return_plans, RDF::Query::Plan::Load->new( $algebra->url, $algebra->graph ));
	} elsif ($type eq 'Update') {
		my $ds		= $algebra->dataset || {};
		my $default	= $ds->{'default'} || [];
		my $named	= $ds->{'named'} || {};
		my $dcount	= scalar(@$default);
		my $ncount	= scalar(@{[ keys %$named ]});
# 		warn 'Update dataset: ' . Dumper($algebra->dataset);
		my @plans;
		
		my @dataset	= ($ds);
		if ($dcount == 1 and $ncount == 0) {
			# if it's just a single named graph to be used as the default graph,
			# then rewrite the pattern to use the named graph (and check to make
			# sure there aren't any GRAPH blocks)
			@dataset	= ();
			@plans		= $self->generate_plans( $algebra->pattern, $context, %args, active_graph => $default->[0] );
		} elsif ($dcount == 0 and $ncount == 0) {
			@dataset	= ();
			@plans		= $self->generate_plans( $algebra->pattern, $context, %args );
		} else {
			@plans		= $self->generate_plans( $algebra->pattern, $context, %args );
		}
		foreach my $p (@plans) {
			push(@return_plans, RDF::Query::Plan::Update->new( $algebra->delete_template, $algebra->insert_template, $p, @dataset ));
		}
	} elsif ($type eq 'Clear') {
		push(@return_plans, RDF::Query::Plan::Clear->new( $algebra->graph ));
	} elsif ($type eq 'Create') {
		my $plan	= RDF::Query::Plan::Constant->new();
		push(@return_plans, $plan);
 	} elsif ($type eq 'Copy') {
 		my $plan	= RDF::Query::Plan::Copy->new( $algebra->from, $algebra->to, $algebra->silent );
		push(@return_plans, $plan);
 	} elsif ($type eq 'Move') {
 		my $plan	= RDF::Query::Plan::Move->new( $algebra->from, $algebra->to, $algebra->silent );
		push(@return_plans, $plan);
	} elsif ($type eq 'Table') {
		my $plan	= RDF::Query::Plan::Constant->new( $algebra->rows );
		push(@return_plans, $plan);
	} else {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan for unknown algebra class $aclass");
	}
	
	if ($constant and scalar(@$constant)) {
		my @plans		= splice( @return_plans );
		@return_plans	= $self->_add_constant_join( $context, $constant, @plans );
	}
	
	foreach my $p (@return_plans) {
		Carp::confess 'not a plan: ' . Dumper($p) unless ($p->isa('RDF::Query::Plan'));
		$p->label( algebra => $algebra );
	}
	
	unless (scalar(@return_plans)) {
		throw RDF::Query::Error::CompilationError (-text => "Cannot generate an execution plan for algebra of type $type", -object => $algebra);
	}
	return @return_plans;
}

sub _csg_plans {
	my $self	= shift;
	my $context	= shift;
	my $st		= shift;
	my $pred	= $st->predicate;
	return unless (blessed($context));
	my $query    = $context->query;
	my @return_plans;
	if (blessed($query) and $pred->isa('RDF::Trine::Node::Resource') and scalar(@{ $query->get_computed_statement_generators( $st->predicate->uri_value ) })) {
		my $csg    = $query->get_computed_statement_generators( $pred->uri_value );
		my @nodes    = $st->nodes;
		my $quad    = (scalar(@nodes) == 4) ? 1 : 0;
		my $mp        = RDF::Query::Plan::ComputedStatement->new( @nodes[0..3], $quad );
		push(@return_plans, $mp);
	}
	return @return_plans;
}

sub _join_plans {
	my $self	= shift;
	my $context	= shift;
	my $triples	= shift;
	my %args	= @_;
	my $config	= $context->options || {};
	
	my $method		= $args{ method };
	my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
	
	my @plans;
	my $opt		= $context->optimize;
	my @slice	= ($opt) ? (0 .. $#{ $triples }) : (0);
	foreach my $i (@slice) {
		my @triples		= @$triples;
		# pick a triple to use as the LHS
		my ($t)	= splice( @triples, $i, 1 );
		
		my @_lhs		= $self->generate_plans( $t, $context, %args );
		my @lhs_plans	= map { [ $_, [$t] ] } @_lhs;
		if (@triples) {
			my @rhs_plans	= $self->_join_plans( $context, \@triples, %args );
			foreach my $i (0 .. $#lhs_plans) {
				foreach my $j (0 .. $#rhs_plans) {
					my $a			= $lhs_plans[ $i ][0];
					my $b			= $rhs_plans[ $j ][0];
					my $algebra_a	= $lhs_plans[ $i ][1];
					my $algebra_b	= $rhs_plans[ $j ][1];
					Carp::confess 'no lhs for join: ' . Dumper(\@lhs_plans) unless (blessed($a));
					Carp::confess 'no rhs for join: ' . Dumper(\@triples, \@rhs_plans) unless (blessed($b));
					foreach ($algebra_a, $algebra_b) {
						unless (ref($_) and reftype($_) eq 'ARRAY') {
							Carp::cluck Dumper($_) 
						}
					}
					foreach my $join_type (@join_types) {
						next if ($join_type eq 'RDF::Query::Plan::Join::PushDownNestedLoop' and $b->subplans_of_type('RDF::Query::Plan::Service'));
						try {
							my @algebras;
							foreach ($algebra_a, $algebra_b) {
								if (reftype($_) eq 'ARRAY') {
									push(@algebras, @$_);
								}
							}
							my %logging_keys;
							if ($method eq 'triples') {
								my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @algebras );
								my $sparql		= $bgp->as_sparql;
								my $bf			= $bgp->bf;
								$logging_keys{ bf }		= $bf;
								$logging_keys{ sparql }	= $sparql;
							} else {
								my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @algebras );
								my $sparql		= $ggp->as_sparql;
								$logging_keys{ sparql }	= $sparql;
							}
							my $plan	= $join_type->new( $b, $a, 0, \%logging_keys );
							push( @plans, [ $plan, [ @algebras ] ] );
						} catch RDF::Query::Error::MethodInvocationError with {
			#				warn "caught MethodInvocationError.";
						};
					}
				}
			}
		} else {
			@plans	= @lhs_plans;
		}
	}
	
	if ($opt) {
		return @plans;
	} else {
		if (@plans) {
			return $plans[0];	# XXX need to figure out what's the 'best' plan here
		} else {
			return;
		}
	}
}

sub _add_constant_join {
	my $self		= shift;
	my $context		= shift;
	my $constant	= shift;
	my @return_plans	= @_;
	my $config		= $context->options || {};
	my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
	while (my $const = shift(@$constant)) {
		my @plans	= splice(@return_plans);
		foreach my $p (@plans) {
			foreach my $join_type (@join_types) {
				try {
					my $plan	= $join_type->new( $p, $const );
					push( @return_plans, $plan );
				} catch RDF::Query::Error::MethodInvocationError with {
	#						warn "caught MethodInvocationError.";
				};
			}
		}
	}
	return @return_plans;
}

sub _path_plans {
	my $self	= shift;
	my $algebra	= shift;
	my $context	= shift;
	my %args	= @_;
	my $path	= $algebra->path;
	my $start	= $algebra->start;
	my $end		= $algebra->end;
	for ($start, $end) {
		if ($_->isa('RDF::Query::Node::Blank')) {
			$_	= $_->make_distinguished_variable;
		}
	}
	
	my $npath	= $self->_normalize_path( $path );
	return $self->__path_plan( $start, $npath, $end, $args{ active_graph }, $context, %args );
}

sub _normalize_path {
	my $self	= shift;
	my $path	= shift;
	if (blessed($path)) {
		return $path;
	}
	
	my $op		= $path->[0];
	my @nodes	= map { $self->_normalize_path($_) } @{ $path }[ 1 .. $#{ $path } ];
	if ($op	eq '0-') {
		$op	= '*';
	} elsif ($op eq '1-') {
		$op	= '+';
	} elsif ($op eq '0-1') {
		$op	= '?';
	} elsif ($op =~ /^-\d+$/) {
		$op	= "0$op";
	}
	
	if ($op eq '!') {
		# re-order the nodes so that forward predicates come first, followed by backwards predicates
		# !(:fwd1|:fwd2|:fwd3|^:bkw1|^:bkw2|^:bkw3)
		@nodes	= sort { blessed($a) ? -1 : (($a->[0] eq '^') ? 1 : -1) } @nodes;
	}
	
	return [$op, @nodes];
}

sub __path_plan {
	my $self	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	my $graph	= shift;
	my $context	= shift;
	my %args	= @_;
	my $distinct	= 1; #$args{distinct} ? 1 : 0;
	my $config		= $context->options || {};
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	
	
	# _simple_path will return an algebra object if the path can be expanded
	# into a simple basic graph pattern (for fixed-length paths)
	if (my $a = $self->_simple_path( $start, $path, $end, $graph )) {
		my ($plan)	= $self->generate_plans( $a, $context, %args, prevent_distinguishing_bnodes => 1 );
		$l->trace('expanded path to pattern: ' . $plan->sse);
		return $plan;
	}
	
	
	if (blessed($path)) {
### X iri Y
		# $path is a resource object: this is a triple (a path of length 1)
		my $s	= $start;
		my $e	= $end;
		my $algebra	= $graph
					? RDF::Query::Algebra::Quad->new( $s, $path, $e, $graph )
					: RDF::Query::Algebra::Triple->new( $s, $path, $e );
		my ($plan)	= $self->generate_plans( $algebra, $context, %args, prevent_distinguishing_bnodes => 1 );
		$l->trace('expanded path to pattern: ' . $plan->sse);
		return $plan;
	}
	
	my ($op, @nodes)	= @$path;
	
# 	if ($op eq 'DISTINCT') {
# 		return $self->__path_plan( $start, $nodes[0], $end, $graph, $context, %args, distinct => 1 );
# 	}
	if ($op eq '!') {
		my $total	= scalar(@nodes);
		my $neg		= scalar(@{ [ grep { not(blessed($_)) and $_->[0] eq '^' } @nodes ] });
		my $pos		= $total - $neg;
		if ($pos == $total) {
### X !(:iri1|...|:irin) Y		
			return RDF::Query::Plan::Path->new( 'NegatedPropertySet', $start, [@nodes], $end, $graph, $distinct, %args );
		} elsif ($neg == $total) {
### X !(^:iri1|...|^:irin)Y
			my @preds	= map { $_->[1] } @nodes;
			return $self->__path_plan($start, ['^', ['!', @preds]], $end, $graph, $context, %args);
		} else {
### X !(:iri1|...|:irii|^:irii+1|...|^:irim) Y 
			my @fwd	= grep { blessed($_) } @nodes;
			my @bwd	= grep { not(blessed($_)) } @nodes;
			my $fplan	= $self->__path_plan($start, ['!', @fwd], $end, $graph, $context, %args);
			my $bplan	= $self->__path_plan($start, ['!', @bwd], $end, $graph, $context, %args);
			return RDF::Query::Plan::Union->new($fplan, $bplan);
		}
	} elsif ($op eq '^') {
### X ^path Y
		return $self->__path_plan( $end, $nodes[0], $start, $graph, $context, %args);
	} elsif ($op eq '/') {
		my $count	= scalar(@nodes);
		if ($count == 1) {
			return $self->__path_plan( $start, $nodes[0], $end, $graph, $context, %args );
		} else {
			my $joinvar		= RDF::Query::Node::Variable->new();
			my @plans		= $self->__path_plan( $start, $nodes[0], $joinvar, $graph, $context, %args );
			foreach my $i (2 .. $count) {
				my $endvar	= ($i == $count) ? $end : RDF::Query::Node::Variable->new();
				my ($rhs)		= $self->__path_plan( $joinvar, $nodes[$i-1], $endvar, $graph, $context, %args );
				push(@plans, $rhs);
				$joinvar	= $endvar;
			}
			my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
			my @jplans;
			foreach my $jclass (@join_types) {
				push(@jplans, $jclass->new( @plans[0,1], 0 ));
			}
			$l->trace("expanded /-path to: " . $jplans[0]->sse);
			return $jplans[0];
		}
	} elsif ($op eq '|') {
### X path1 | path2 Y
		my @plans	= map { $self->__path_plan($start, $_, $end, $graph, $context, %args) } @nodes;
		return RDF::Query::Plan::Union->new(@plans);
	} elsif ($op eq '?') {
### X path? Y
		my $upath	= $nodes[0];
		my $zplan	= $self->__path_plan($start, ['0', $upath], $end, $graph, $context, %args );
		my $oplan	= $self->__path_plan($start, $upath, $end, $graph, $context, %args);
		
		# project away any non-distinguished variables introduced by plan-to-bgp expansion
		my @vars	= grep { blessed($_) and $_->isa('RDF::Query::Node::Variable') } ($start, $end);
		my $odplan	= RDF::Query::Plan::Project->new( $oplan, \@vars );
		
		my $pplan	= RDF::Query::Plan::Union->new($zplan, $odplan);
		
		# distinct the results
		my $plan	= RDF::Query::Plan::Distinct->new( $pplan );
		return $plan;
	} elsif ($op eq '*') {
### X path* Y
		return RDF::Query::Plan::Path->new( 'ZeroOrMorePath', $start, $nodes[0], $end, $graph, $distinct, %args );
	} elsif ($op eq '+') {
### X path+ Y
		return RDF::Query::Plan::Path->new( 'OneOrMorePath', $start, $nodes[0], $end, $graph, $distinct, %args );
	} elsif ($op eq '0') {
### X path{0} Y
		return RDF::Query::Plan::Path->new( 'ZeroLengthPath', $start, $nodes[0], $end, $graph, $distinct, %args );
	} elsif ($op =~ /^\d+$/) {
### X path{n} Y where n > 0
		my $count	= $op;
		if ($count == 1) {
			return $self->__path_plan( $start, $nodes[0], $end, $graph, $context, %args );
		} else {
			my $joinvar		= RDF::Query::Node::Variable->new();
			my @plans		= $self->__path_plan( $start, $nodes[0], $joinvar, $graph, $context, %args );
			foreach my $i (2 .. $count) {
				my $endvar	= ($i == $count) ? $end : RDF::Query::Node::Variable->new();
				my ($rhs)		= $self->__path_plan( $joinvar, $nodes[0], $endvar, $graph, $context, %args );
				push(@plans, $rhs);
				$joinvar	= $endvar;
			}
			my @join_types	= RDF::Query::Plan::Join->join_classes( $config );
			my @jplans;
			
			my @plan	= shift(@plans);
			while (@plans) {
				my $q	= shift(@plans);
				my @p;
				foreach my $p (@plan) {
					foreach my $jclass (@join_types) {
						push(@p, $jclass->new( $p, $q, 0 ));
					}
				}
				@plan	= @p;
			}
			return $plan[0];
		}
	} elsif ($op =~ /^(\d+)-(\d+)$/) {
### X path{n,m} Y
		my ($n,$m)	= split('-', $op, 2);
# 		warn "$1- to $2-length path";
		my @range	= sort { $a <=> $b } ($n, $m);
		my $from	= $range[0];
		my $to		= $range[1];
		my @plans;
		foreach my $i ($from .. $to) {
			if ($i == 0) {
				push(@plans, $self->__path_plan($start, ['0', []], $end, $graph, $context, %args ));
			} else {
				push(@plans, $self->__path_plan( $start, [$i, $nodes[0]], $end, $graph, $context, %args ));
			}
		}
		while (scalar(@plans) > 1) {
			my $lhs	= shift(@plans);
			my $rhs	= shift(@plans);
			unshift(@plans, RDF::Query::Plan::Union->new( $lhs, $rhs ));
		}
		return $plans[0];
	} elsif ($op =~ /^(\d+)-$/) {
### X path{n,} Y where n > 0
		my ($min)	= split('-', $op);
		# expand :p{n,} into :p{n}/:p*
		my $path		= [ '/', [ $1, @nodes ], [ '*', @nodes ] ];
		my $plan		= $self->__path_plan( $start, $path, $end, $graph, $context, %args );
		return $plan;
	} else {
		throw RDF::Query::Error -text => "Cannot generate plan for unknown path type $op";
	}
}

sub _simple_path {
	my $self	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	my $graph	= shift;
	if (blessed($path)) {
		return ($graph)
			? RDF::Query::Algebra::Quad->new( $start, $path, $end, $graph )
			: RDF::Query::Algebra::Triple->new( $start, $path, $end );
	}
	return unless (reftype($path) eq 'ARRAY');
	my $op	= $path->[0];
	if ($op eq '/') {
		my @patterns;
		my @jvars	= map { RDF::Query::Node::Variable->new() } (2 .. $#{ $path });
		foreach my $i (1 .. $#{ $path }) {
			my $s		= ($i == 1) ? $start : $jvars[ $i-2 ];
			my $e		= ($i == $#{ $path }) ? $end : $jvars[ $i-1 ];
			my $triple	= $self->_simple_path( $s, $path->[ $i ], $e, $graph );
			return unless ($triple);
			push(@patterns, $triple);
		}
		my @triples	= map { $_->isa('RDF::Query::Algebra::BasicGraphPattern') ? $_->triples : $_ } @patterns;
		return RDF::Query::Algebra::BasicGraphPattern->new( @triples );
	} elsif ($op eq '^' and scalar(@$path) == 2 and blessed($path->[1])) {
		return ($graph)
			? RDF::Query::Algebra::Quad->new( $end, $path->[1], $start, $graph )
			: RDF::Query::Algebra::Triple->new( $end, $path->[1], $start );
	} elsif ($op =~ /^\d+$/ and $op == 1) {
		return $self->_simple_path( $start, $path->[1], $end, $graph );
	}
	
	return;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name;

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. These identifiers are recognized:

 * 'A' - An RDF::Query::Algebra object
 * 'b' - A boolean integer value (0 or 1)
 * 'E' - An expression (either an RDF::Query::Expression object or an RDF node)
 * 'i' - An integer
 * 'J' - A valid Project node (an RDF::Query::Expression object or an Variable node)
 * 'N' - An RDF node
 * 'P' - A RDF::Query::Plan object
 * 'q' - A RDF::Query object
 * 'Q' - An RDF::Trine::Statement::Quad object
 * 's' - A string
 * 'T' - An RDF::Trine::Statement object
 * 'u' - A valid URI string
 * 'V' - A variable binding set (an object of type RDF::Query::VariableBindings)
 * 'w' - A bareword string
 * 'W' - An RDF node or wildcard ('*')
 * '*X' - A list of X nodes (where X is another identifier scalar)
 * '\X' - An array reference of X nodes (where X is another identifier scalar)

=cut

sub plan_prototype;

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data;


=item C<< subplans_of_type ( $type [, $block] ) >>

Returns a list of Plan objects matching C<< $type >> (tested with C<< isa >>).
If C<< $block >> is given, then matching stops descending a subtree if the current
node is of type C<< $block >>, continuing matching on other subtrees.
This list includes the current plan object if it matches C<< $type >>, and is
generated in infix order.

=cut

sub subplans_of_type {
	my $self	= shift;
	my $type	= shift;
	my $block	= shift;
	
	return if ($block and $self->isa($block));
	
	my @patterns;
	push(@patterns, $self) if ($self->isa($type));
	
	
	foreach my $p ($self->plan_node_data) {
		if (blessed($p) and $p->isa('RDF::Query::Plan')) {
			push(@patterns, $p->subplans_of_type($type, $block));
		}
	}
	return @patterns;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
