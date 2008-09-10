# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

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

use RDF::Query::Plan::Aggregate;
use RDF::Query::Plan::BasicGraphPattern;
use RDF::Query::Plan::Constant;
use RDF::Query::Plan::Distinct;
use RDF::Query::Plan::Filter;
use RDF::Query::Plan::Join::NestedLoop;
use RDF::Query::Plan::Join::PushDownNestedLoop;
use RDF::Query::Plan::Limit;
use RDF::Query::Plan::Offset;
use RDF::Query::Plan::Project;
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Service;
use RDF::Query::Plan::Sort;
use RDF::Query::Plan::Triple;
use RDF::Query::Plan::Union;

use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

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
	die "sse not implemented on $self";
}

=item C<< referenced_variables >>

Returns a list of variable names that are referenced by this plan.

=cut

sub referenced_variables {
	my $self	= shift;
	my $refs	= $self->[0]{referenced_variables};
	return @{ $refs };
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
	my $model	= $context->model;
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
		my @plans	= map { RDF::Query::Plan::Aggregate->new( $_, \@groups, @ops ) } @base;
		@return_plans	= @plans;
	} elsif ($type eq 'Distinct') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Distinct->new( $_ ) } @base;
		@return_plans	= @plans;
	} elsif ($type eq 'Filter') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my $expr	= $algebra->expr;
		my @plans	= map { RDF::Query::Plan::Filter->new( $_, $expr ) } @base;
		@return_plans	= @plans;
	} elsif ($type eq 'BasicGraphPattern' or $type eq 'GroupGraphPattern') {
		my $query	= $context->query;
		my $csg		= (blessed($query) and scalar(@{ $query->get_computed_statement_generators })) ? 1 : 0;
		my $method	= ($type eq 'BasicGraphPattern') ? 'triples' : 'patterns';
		my @triples	= $algebra->$method();
# 		if ($type eq 'BasicGraphPattern' and $model->supports('basic_graph_pattern') and not($csg) and scalar(@triples) > 1) {
# 			my @plan_triples;
# 			foreach my $t (@triples) {
# 				my @nodes	= $t->nodes;
# 				foreach my $i (0 .. $#nodes) {
# 					if ($nodes[$i]->isa('RDF::Trine::Node::Blank')) {
# 						$nodes[$i]	= _make_blank_distinguished_variable( $nodes[$i] );
# 					}
# 				}
# 				if (scalar(@nodes) == 4) {
# 					push(@plan_triples, RDF::Trine::Statement::Quad->new( @nodes ));
# 				} else {
# 					push(@plan_triples, RDF::Trine::Statement->new( @nodes ));
# 				}
# 			}
# 			my $plan		= RDF::Query::Plan::BasicGraphPattern->new( @triples );
# 			@return_plans	= ($plan);
# 		}
		
		if (scalar(@triples) == 0) {
			my $v		= RDF::Query::VariableBindings->new( {} );
			my $plan	= RDF::Query::Plan::Constant->new( $v );
			@return_plans	= $plan;
		} elsif (scalar(@triples) == 1) {
			@return_plans	= $self->generate_plans( @triples, $context, %args );
		} else {
			@return_plans	= map { $_->[0] } $self->_triple_join_plans( $context, \@triples, %args, method => $method );
		}
	} elsif ($type eq 'Limit') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Limit->new( $_, $algebra->limit ) } @base;
		@return_plans	= @plans;
	} elsif ($type eq 'NamedGraph') {
		my @plans	= $self->generate_plans( $algebra->pattern, $context, %args );
		@return_plans	= @plans;
	} elsif ($type eq 'Offset') {
		my @base	= $self->generate_plans( $algebra->pattern, $context, %args );
		my @plans	= map { RDF::Query::Plan::Offset->new( $_, $algebra->offset ) } @base;
		@return_plans	= @plans;
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
		@return_plans	= @plans;
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
		@return_plans	= @plans;
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
		@return_plans	= @plans;
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
		@return_plans	= @plans;
	} elsif ($type eq 'Triple' or $type eq 'Quad') {
		my @nodes	= $algebra->nodes;
		foreach my $i (0 .. $#nodes) {
			if ($nodes[$i]->isa('RDF::Trine::Node::Blank')) {
				$nodes[$i]	= _make_blank_distinguished_variable( $nodes[$i] );
			}
		}
		my $plan	= (scalar(@nodes) == 4)
					? RDF::Query::Plan::Quad->new( @nodes, { sparql => $algebra->as_sparql } )
					: RDF::Query::Plan::Triple->new( @nodes, { sparql => $algebra->as_sparql, bf => $algebra->bf } );
		@return_plans	= $plan;
	} elsif ($type eq 'Union') {
		my @plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->patterns;
		# XXX
		my $plan	= RDF::Query::Plan::Union->new( map { $_->[0] } @plans );
		@return_plans	= $plan;
	} else {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan for unknown algebra class $aclass");
	}
	
	if ($constant and scalar(@$constant)) {
		my @plans		= splice( @return_plans );
		@return_plans	= $self->_add_constant_join( $constant, @plans );
	}
	
	return @return_plans;
}

=item C<< prune_plans ( $context, @plans ) >>

=cut

sub prune_plans {
	my $self	= shift;
	my $context	= shift;
	my @plans	= @_;
	my $cm		= $context->costmodel;
	my ($plan)	= map { $_->[0] } reduce { $a->[1] < $b->[1] ? $a : $b } map { [ $_, $cm->cost($_, $context) ] } @plans;
	return $plan;
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
							my $plan	= $join_type->new( $a, $b, 0, \%logging_keys );
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
		my $cm		= $context->costmodel;
		my ($plan)	= map { $_->[0] } reduce { $a->[1] < $b->[1] ? $a : $b } map { [ $_, ($cm ? $cm->cost($_->[0], $context) : 0) ] } @plans;
		return $plan;
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

sub _make_blank_distinguished_variable {
	my $blank	= shift;
	my $id		= $blank->blank_identifier;
	my $name	= '__ndv_' . $id;
	my $var		= RDF::Trine::Node::Variable->new( $name );
	return $var;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
