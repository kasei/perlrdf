# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

=head1 VERSION

This document describes RDF::Query::Plan version 2.201, released 30 January 2010.

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
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Service;
use RDF::Query::Plan::Sort;
use RDF::Query::Plan::Triple;
use RDF::Query::Plan::ThresholdUnion;
use RDF::Query::Plan::Union;
use RDF::Query::Plan::SubSelect;

use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.201';
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
		return $v->sse( { namespaces => \%ns }, "${indent}${more}" );
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
	my $l		= Log::Log4perl->get_logger("rdf.query.algebra.plan");
	unless (blessed($algebra) and $algebra->isa('RDF::Query::Algebra')) {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan with a non-algebra object $algebra");
	}
	
	$l->trace("generating query plan for $algebra");
	my ($project);
	my $constant	= $args{ constants };
# 	unless ($algebra->isa('RDF::Query::Algebra::Project') or not ($algebra->is_solution_modifier)) {
# 		# we're below all the solution modifiers, so now's the time to add any constant data
# 		$constant	= delete $args{ constants };
# 	}
	
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
		my @ops		= $algebra->ops;
		my @having	= $algebra->having;
		my @plans	= map { RDF::Query::Plan::Aggregate->new( $_, \@groups, expressions => \@ops, having => \@having ) } @base;
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
	} elsif ($type eq 'BasicGraphPattern' or $type eq 'GroupGraphPattern') {
		my $query	= $context->query;
		my $csg		= (blessed($query) and scalar(@{ $query->get_computed_statement_generators })) ? 1 : 0;
		my $method	= ($type eq 'BasicGraphPattern') ? 'triples' : 'patterns';
		my @triples	= $algebra->$method();
		
		if (scalar(@triples) == 0) {
			if ($args{ named_graph }) {
				my @nodes	= map { RDF::Query::Node::Variable->new($_) } qw(s p o);
				push(@nodes, $args{ named_graph });
				my $plan	= RDF::Query::Plan::Distinct->new( 
								RDF::Query::Plan::Project->new(
									RDF::Query::Plan::Quad->new( @nodes, { sparql => '{}' } ),
									[ $args{ named_graph } ]
								)
							);
				push(@return_plans, $plan);
			} else {
				my $v		= RDF::Query::VariableBindings->new( {} );
				my $plan	= RDF::Query::Plan::Constant->new( $v );
				push(@return_plans, $plan);
			}
		} elsif (scalar(@triples) == 1) {
			push(@return_plans, $self->generate_plans( @triples, $context, %args ));
		} else {
			push(@return_plans, map { $_->[0] } $self->_triple_join_plans( $context, \@triples, %args, method => $method ));
		}
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
			push(@plans, RDF::Query::Plan::Project->new( $plan, $vars ));
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
		my @nodes	= $st->nodes;
		my $plan	= (scalar(@nodes) == 4)
					? RDF::Query::Plan::Quad->new( @nodes, { sparql => $algebra->as_sparql } )
					: RDF::Query::Plan::Triple->new( @nodes, { sparql => $algebra->as_sparql, bf => $algebra->bf } );
		push(@return_plans, $plan);
	} elsif ($type eq 'Union') {
		my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->patterns;
		# XXX
		my $plan	= RDF::Query::Plan::Union->new( map { $_->[0] } @plans );
		push(@return_plans, $plan);
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

sub _triple_join_plans {
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
		my @lhs_plans	= map { [ $_, [$t] ] } $self->generate_plans( $t, $context, %args );
		if (@triples) {
			my @rhs_plans	= $self->_triple_join_plans( $context, \@triples, %args );
			foreach my $i (0 .. $#lhs_plans) {
				foreach my $j (0 .. $#rhs_plans) {
					my $a			= $lhs_plans[ $i ][0];
					my $b			= $rhs_plans[ $j ][0];
					my $algebra_a	= $lhs_plans[ $i ][1];
					my $algebra_b	= $rhs_plans[ $j ][1];
					foreach my $join_type (@join_types) {
						try {
							my @algebras	= (@$algebra_a, @$algebra_b);
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
		return $plans[0];	# XXX need to figure out what's the 'best' plan here
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

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name;

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. These identifiers are recognized:

* 'P' - A RDF::Query::Plan object
* 'T' - An RDF::Trine::Statement object
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
