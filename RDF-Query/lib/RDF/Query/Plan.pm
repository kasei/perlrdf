# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

=head1 VERSION

This document describes RDF::Query::Plan version 2.900.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);
use Scalar::Util qw(blessed reftype);
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
use RDF::Query::Plan::Not;
use RDF::Query::Plan::Exists;
use RDF::Query::Plan::Offset;
use RDF::Query::Plan::Project;
use RDF::Query::Plan::Extend;
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Service;
use RDF::Query::Plan::Sort;
use RDF::Query::Plan::Triple;
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

use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.900';
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

=item C<< sse >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
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
	return "(${name} " . join(' ', @args) . ")";
}

sub _sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= shift;
	my $p		= shift;
	my $list	= shift;
	if ($p =~ m/^[PTNWEJVibswu]$/) {
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
	} elsif ($p =~ m/^[PTNWEJVibswu\\*]{2,}$/) {
		my @args;
		foreach my $p2 (split(//, $p)) {
			my $v	= shift(@$list);
			push(@args, $self->_sse($context, $indent, $more, $p2, [$v]));
		}
		return '(' . join(' ', @args) . ')';
	} else {
		die "unrecognized plan node prototype '$p'";
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
	my %args	= @_;
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
								$l->debug("TODO: Potential optimization for COUNT(*) on 1-triple BGP: " . $bgp->sse({ indent => '  ' }, ''));
								my $vars	= $algebra->vars;
								my $alias	= $vars->[0];
								my $name	= $alias->name;
								my $done	= 0;
								my $model	= $context->model;
								my $code	= sub {
									return if ($done);
									$done	= 1;
									my $count	= $model->count_statements( $triples[0]->nodes );
									my $vb	= RDF::Query::VariableBindings->new( {
										$name => RDF::Query::Node::Literal->new($count, undef, 'http://www.w3.org/2001/XMLSchema#integer')
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
	my $constant	= $args{ constants };
	
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
	} elsif ($type eq 'Not') {
		my @patt	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @npatt	= $self->generate_plans( $algebra->not_pattern, $context, %args );
		foreach my $p (@patt) {
			foreach my $n (@npatt) {
				push(@return_plans, RDF::Query::Plan::Not->new( $p, $n ));
			}
		}
	} elsif ($type eq 'Exists') {
		my @patt	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @npatt	= $self->generate_plans( $algebra->exists_pattern, $context, %args );
		foreach my $p (@patt) {
			foreach my $n (@npatt) {
				push(@return_plans, RDF::Query::Plan::Exists->new( $p, $n, $algebra->not_flag ));
			}
		}
	} elsif ($type eq 'Filter') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my $expr	= $algebra->expr;
		my @plans	= map { RDF::Query::Plan::Filter->new( $expr, $_ ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'BasicGraphPattern') {
		my @triples	= map { $_->distinguish_bnode_variables } $algebra->triples;
		my @normal_triples;
		my @csg_triples;
		foreach my $t (@triples) {
			if (my @csg_plans = $self->_csg_plans( $context, $t )) {
				push(@csg_triples, $t);
			} else {
				push(@normal_triples, $t);
			}
		}
		
		my @plans;
		if (scalar(@normal_triples) == 0) {
			if ($args{ named_graph }) {
				my @nodes	= map { RDF::Query::Node::Variable->new($_) } qw(s p o);
				push(@nodes, $args{ named_graph });
				my $plan	= RDF::Query::Plan::Distinct->new( 
								RDF::Query::Plan::Project->new(
									RDF::Query::Plan::Quad->new( @nodes, { sparql => '{}' } ),
									[ $args{ named_graph } ]
								)
							);
				push(@plans, $plan);
			} else {
				my $v		= RDF::Query::VariableBindings->new( {} );
				my $plan	= RDF::Query::Plan::Constant->new( $v );
				push(@plans, $plan);
			}
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
			my @join_types	= RDF::Query::Plan::Join->join_classes;
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
		my @patterns	= $algebra->patterns();
		
		my @plans;
		if (scalar(@patterns) == 0) {
			if ($args{ named_graph }) {
				my @nodes	= map { RDF::Query::Node::Variable->new($_) } qw(s p o);
				push(@nodes, $args{ named_graph });
				my $plan	= RDF::Query::Plan::Distinct->new( 
								RDF::Query::Plan::Project->new(
									RDF::Query::Plan::Quad->new( @nodes, { sparql => '{}' } ),
									[ $args{ named_graph } ]
								)
							);
				push(@plans, $plan);
			} else {
				my $v		= RDF::Query::VariableBindings->new( {} );
				my $plan	= RDF::Query::Plan::Constant->new( $v );
				push(@plans, $plan);
			}
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
		# we push 'named_graph' down as part of %arg here so that empty BGPs ({}) can be \
		# handled specially in named graphs -- namely, {} should be executed as an empty BGP \
		# when in a GraphGraphPattern so GRAPH ?g {} ends up returning all the valid graph names, \
		# instead of being optimized away into an empty variable binding.
		my @plans	= $self->generate_plans( $algebra->pattern, $context, %args, named_graph => $algebra->graph );
		push(@return_plans, @plans);
	} elsif ($type eq 'Offset') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Offset->new( $algebra->offset, $_ ) } @base;
		push(@return_plans, @plans);
	} elsif ($type eq 'Optional') {
		# just like a BGP or GGP, but we have to pass the optional flag to the join constructor
		my @patterns	= ($algebra->pattern, $algebra->optional);
		my @base_plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } @patterns;
		my @join_types	= RDF::Query::Plan::Join->join_classes;
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
						my $plan	= $join_type->new( $a, $b, 1, {  } );
						push( @plans, $plan );
					} catch RDF::Query::Error::MethodInvocationError with {
#						warn "caught MethodInvocationError.";
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
			@base		= $self->_add_constant_join( $constant, @plans );
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
			my $ns			= $context->ns;
			my $sparql		= join("\n",
								(map { sprintf("PREFIX %s: <%s>", $_, $ns->{$_}) } (keys %$ns)),
								sprintf("SELECT * WHERE %s", $pattern->as_sparql({namespaces => $ns}, ''))
							);
			push(@plans, RDF::Query::Plan::Service->new( $algebra->endpoint->uri_value, $plan, $sparql ));
		}
		push(@return_plans, @plans);
	} elsif ($type eq 'SubSelect') {
		my $query	= $algebra->query;
		push(@return_plans, RDF::Query::Plan::SubSelect->new( $query ));
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
		my $st		= $algebra->distinguish_bnode_variables;
		my $pred    = $st->predicate;
		if (my @csg_plans = $self->_csg_plans( $context, $st )) {
			push(@return_plans, @csg_plans);
		} else {
			my @nodes    = $st->nodes;
			my $plan    = (scalar(@nodes) == 4)
						? RDF::Query::Plan::Quad->new( @nodes, { sparql => $algebra->as_sparql } )
						: RDF::Query::Plan::Triple->new( @nodes, { sparql => $algebra->as_sparql, bf => $algebra->bf } );
			push(@return_plans, $plan);
		}
	} elsif ($type eq 'Path') {
		my @plans	= $self->_path_plans( $algebra, $context );
		push(@return_plans, @plans);
	} elsif ($type eq 'Union') {
		my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->patterns;
		my $plan	= RDF::Query::Plan::Union->new( map { $_->[0] } @plans );
		push(@return_plans, $plan);
	} elsif ($type eq 'Sequence') {
		my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->patterns;
		my $plan	= RDF::Query::Plan::Sequence->new( map { $_->[0] } @plans );
		push(@return_plans, $plan);
	} elsif ($type eq 'Load') {
		push(@return_plans, RDF::Query::Plan::Load->new( $algebra->url, $algebra->graph ));
	} elsif ($type eq 'Update') {
		my @plans	= $self->generate_plans( $algebra->pattern, $context, %args );
		foreach my $p (@plans) {
			push(@return_plans, RDF::Query::Plan::Update->new( $algebra->delete_template, $algebra->insert_template, $p ));
		}
	} elsif ($type eq 'Clear') {
		push(@return_plans, RDF::Query::Plan::Clear->new( $algebra->graph ));
	} else {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan for unknown algebra class $aclass");
	}
	
	if ($constant and scalar(@$constant)) {
		my @plans		= splice( @return_plans );
		@return_plans	= $self->_add_constant_join( $constant, @plans );
	}
	
	foreach my $p (@return_plans) {
		$p->label( algebra => $algebra );
	}
	
	return @return_plans;
}

sub _csg_plans {
	my $self	= shift;
	my $context	= shift;
	my $st		= shift;
	my $pred	= $st->predicate;
	Carp::confess unless (blessed($context));
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
	
	my $method		= $args{ method };
	my @join_types	= RDF::Query::Plan::Join->join_classes;
	
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
	my $constant	= shift;
	my @return_plans	= @_;
	my @join_types	= RDF::Query::Plan::Join->join_classes;
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
	my $path	= $algebra->path;
# 	if ($algebra->bounded_length) {
# 		warn "Fixed length path";
		my $start	= $algebra->start;
		my $end		= $algebra->end;
		return $self->__path_plan( $start, $path, $end, $context );
# 	} else {
# 		throw RDF::Query::Error -text => "Unbounded paths not implemented yet";
# 	}
}

sub __path_plan {
	my $self	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	my $context	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	if (blessed($path)) {
		my $s		= ($start->isa('RDF::Query::Node::Blank')) ? $start->make_distinguished_variable : $start;
		my $e		= ($end->isa('RDF::Query::Node::Blank')) ? $end->make_distinguished_variable : $end;
		my $plan	= RDF::Query::Plan::Triple->new( $s, $path, $e );
		$l->trace('expanded path to triple pattern: ' . $plan->sse);
		return $plan;
	}
	
	my ($op, @nodes)	= @$path;
	if ($op eq '!') {
		my $model	= $context->model;
		my $var		= RDF::Query::Node::Variable->new();
		my $nvar	= RDF::Query::Node::Variable->new();
		my $triple	= RDF::Query::Algebra::Triple->new( $start, $var, $end );
		my $ntriple	= RDF::Query::Algebra::Triple->new( $end, $nvar, $start );
		my @plans;
		push(@plans, $self->generate_plans( $triple, $context ));
		push(@plans, $self->generate_plans( $ntriple, $context ));
		
		my (%not, %revnot);
		foreach my $n (@nodes) {
			if (blessed($n)) {
				$not{ $n->uri_value }++;
			} else {
				$revnot{ $n->[1]->uri_value }++;
			}
		}
		
		$_->execute( $context ) for (@plans);
		my $code	= sub {
			while (1) {
				return unless (@plans);
				my $row	= $plans[0]->next;
				unless (blessed($row)) {
					shift(@plans);
					next;
				}
				if (my $p = $row->{ $var->name }) {
					next if (exists $not{ $p->uri_value });
				} else {
					my $np	= $row->{ $nvar->name };
					next if (exists $not{ $np->uri_value });
				}
				return $row;
			}
		};
		my $iter	= RDF::Trine::Iterator::Bindings->new( $code, [] );
		my $nplan	= RDF::Query::Plan::Iterator->new( $iter );
# 		my $dnplan	= RDF::Query::Plan::Distinct->new( $nplan );
		return $nplan;
	} elsif ($op eq '*') {
		return RDF::Query::Plan::Path->new( $op, $nodes[0], $start, $end );
	} elsif ($op eq '+') {
		return RDF::Query::Plan::Path->new( $op, $nodes[0], $start, $end );
	} elsif ($op eq '?') {
		my $node	= shift(@nodes);
		my $plan	= $self->__path_plan( $start, $node, $end, $context );
		my $zero	= $self->__zero_length_path_plan( $start, $end, $context );
		my $union	= RDF::Query::Plan::Union->new( $zero, $plan );
		return $union;
	} elsif ($op eq '^') {
		my $node	= shift(@nodes);
		return $self->__path_plan( $end, $node, $start, $context );
	} elsif ($op eq '/') {
		my $count	= scalar(@nodes);
		if ($count == 1) {
			return $self->__path_plan( $start, $nodes[0], $end, $context );
		} else {
			my $joinvar		= RDF::Query::Node::Variable->new();
			my @plans		= $self->__path_plan( $start, $nodes[0], $joinvar, $context );
			foreach my $i (2 .. $count) {
				my $endvar	= ($i == $count) ? $end : RDF::Query::Node::Variable->new();
				my ($rhs)		= $self->__path_plan( $joinvar, $nodes[$i-1], $endvar, $context );
				push(@plans, $rhs);
				$joinvar	= $endvar;
			}
			my @join_types	= RDF::Query::Plan::Join->join_classes;
			my @jplans;
			foreach my $jclass (@join_types) {
				push(@jplans, $jclass->new( @plans[0,1], 0 ));
			}
			$l->trace("expanded /-path to: " . $jplans[0]->sse);
			return $jplans[0];
		}
	} elsif ($op eq '|') {
		my $lhs		= $self->__path_plan( $start, $nodes[0], $end, $context );
		my $rhs		= $self->__path_plan( $start, $nodes[1], $end, $context );
		my $union	= RDF::Query::Plan::Union->new( $lhs, $rhs );
		return $union;
	} elsif ($op =~ /^(\d+)$/) {
# 		warn "$1-length path";
		my $count	= $1;
		if ($count == 0) {
			my $zero	= $self->__zero_length_path_plan( $start, $end, $context );
			return $zero;
		} elsif ($count == 1) {
			return $self->__path_plan( $start, $nodes[0], $end, $context );
		} else {
			my $joinvar		= RDF::Query::Node::Variable->new();
			my @plans		= $self->__path_plan( $start, $nodes[0], $joinvar, $context );
			foreach my $i (2 .. $count) {
				my $endvar	= ($i == $count) ? $end : RDF::Query::Node::Variable->new();
				my ($rhs)		= $self->__path_plan( $joinvar, $nodes[0], $endvar, $context );
				push(@plans, $rhs);
				$joinvar	= $endvar;
			}
			my @join_types	= RDF::Query::Plan::Join->join_classes;
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
# 		warn "$1- to $2-length path";
		my @range	= sort { $a <=> $b } ($1, $2);
		my $from	= $range[0];
		my $to		= $range[1];
		my @plans;
		foreach my $i ($from .. $to) {
			if ($i == 0) {
				my $zero	= $self->__zero_length_path_plan( $start, $end, $context );
				push(@plans, $zero);
			} else {
				push(@plans, $self->__path_plan( $start, [$i, $nodes[0]], $end, $context ));
			}
		}
		while (scalar(@plans) > 1) {
			my $lhs	= shift(@plans);
			my $rhs	= shift(@plans);
			unshift(@plans, RDF::Query::Plan::Union->new( $lhs, $rhs ));
		}
		return $plans[0];
	} elsif ($op =~ /^(\d+)-$/) {
		throw RDF::Query::Error -text => "Unbounded paths not implemented yet";
	} else {
		throw RDF::Query::Error -text => "Cannot generate plan for unknown path type $op";
	}
}

sub __zero_length_path_plan {
	my $self	= shift;
	my $start	= shift;
	my $end		= shift;
	my $context	= shift;
	my $model	= $context->model;
	my @iters;
	push(@iters, scalar($model->subjects));
#	push(@iters, scalar($model->predicates));
	push(@iters, scalar($model->objects));
	my %vars;
	my $no_literals	= 0;
	if ($start->isa('RDF::Query::Node::Variable')) {
		$vars{ $start->name }++;
		$no_literals	= 1;
	}
	$vars{ $end->name }++ if ($end->isa('RDF::Query::Node::Variable'));
	
	my $code	= sub {
		while (1) {
			return unless scalar(@iters);
			my $node	= $iters[0]->next;
			if ($node) {
				if ($no_literals) {
					next if ($node->isa('RDF::Query::Node::Literal'));
				}
				my $vb	= RDF::Query::VariableBindings->new( { map { $_ => $node } (keys %vars) } );
				return $vb;
			} else {
				shift(@iters);
			}
		}
	};
	my $iter	= RDF::Trine::Iterator::Bindings->new( $code, [] );
	my $nodes	= RDF::Query::Plan::Iterator->new( $iter );
	my $plan	= RDF::Query::Plan::Distinct->new( $nodes );
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name;

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. These identifiers are recognized:

 * 'P' - A RDF::Query::Plan object
 * 'T' - An RDF::Trine::Statement object
 * 'A' - An RDF::Query::Algebra object
 * 'Q' - An RDF::Trine::Statement::Quad object
 * 'N' - An RDF node
 * 'W' - An RDF node or wildcard ('*')
 * 'E' - An expression (either an RDF::Query::Expression object or an RDF node)
 * 'J' - A valid Project node (an RDF::Query::Expression object or an Variable node)
 * 'V' - A variable binding set (an object of type RDF::Query::VariableBindings)
 * 'u' - A valid URI string
 * 'i' - An integer
 * 'b' - A boolean integer value (0 or 1)
 * 's' - A string
 * 'w' - A bareword string
 * '\X' - An array reference of X nodes (where X is another identifier scalar)
 * '*X' - A list of X nodes (where X is another identifier scalar)
 * 'Q' - A RDF::Query object

=cut

sub plan_prototype;

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data;

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
