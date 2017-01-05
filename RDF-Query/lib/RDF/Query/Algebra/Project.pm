# RDF::Query::Algebra::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Project - Algebra class for projection

=head1 VERSION

This document describes RDF::Query::Algebra::Project version 2.918.

=cut

package RDF::Query::Algebra::Project;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(reftype blessed refaddr);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<< new ( $pattern, \@vars_and_exprs ) >>

Returns a new Project structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $vars	= shift;
	unless (blessed($pattern)) {
		throw RDF::Query::Error::MethodInvocationError -text => "Sub-pattern in RDF::Query::Algebra::Project constructor must be a valid algebra object";
	}
	unless (reftype($vars) eq 'ARRAY' and not(blessed($vars))) {
		throw RDF::Query::Error::MethodInvocationError -text => "Variable list in RDF::Query::Algebra::Project constructor must be an ARRAY reference";
	}
	my @vars;
	foreach my $v (@$vars) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v);
		} else {
			push(@vars, $v->alias);
		}
	}
	return bless( [ $pattern, \@vars ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $vars	= $self->vars;
	return ($pattern, $vars);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< vars >>

Returns the vars to be projected to.

=cut

sub vars {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my $vars	= join(' ',
					map {
						($_->isa('RDF::Query::Node::Variable')) ? '?' . $_->name : $_->sse( $context )
					} @{ $self->vars }
				);
	return sprintf(
		"(project (%s)\n${prefix}${indent}%s\n${prefix})",
		$vars,
		$self->pattern->sse( $context, "${prefix}${indent}" ),
	);
}

sub _from_sse {
	my $class	= shift;
	my $context	= $_[1];
	for ($_[0]) {
		if (m/^[(]project\s+[(]\s*/) {
			my @nodes;
			s/^[(]project\s+[(]\s*//;
			do {
				push(@nodes, RDF::Trine::Node->from_sse( $_[0], $context ));
			} until (m/\s*[)]/);
			if (m/^\s*[)]/) {
				s/^\s*[)]\s*//;
			} else {
				throw RDF::Trine::Error -text => "Cannot parse end-of-project-vars from SSE string: >>$_<<";
			}
			
			my ($pattern)	= RDF::Query::Algebra->from_sse( $context, $_[0] );
			
			if (m/^\s*[)]/) {
				s/^\s*[)]\s*//;
				warn "project: " . Dumper(\@nodes);
				return RDF::Query::Algebra::Project->new( $pattern, \@nodes );
			} else {
				throw RDF::Trine::Error -text => "Cannot parse end-of-project from SSE string: >>$_<<";
			}
		} else {
			throw RDF::Trine::Error -text => "Cannot parse project from SSE string: >>$_<<";
		}
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	
	my $pattern	= $self->pattern;
	$context->{ force_ggp_braces }++;
	
	my ($vars, $_sparql);
	my $vlist	= $self->vars;
	my (@vars);
	foreach my $k (@$vlist) {
		if ($k->isa('RDF::Query::Expression')) {
			push(@vars, $k->sse({}, ''));
		} elsif ($k->isa('RDF::Query::Node::Variable')) {
			push(@vars, '?' . $k->name);
		} else {
			push(@vars, $k);
		}
	}
	
	my $aggregate	= 0;
	my $group	= '';
	my $having	= '';
	my $order	= '';
	my %agg_projections;
	my @aggs	= $pattern->subpatterns_of_type( 'RDF::Query::Algebra::Aggregate' );
	if (@aggs) {
		# aggregate check
		my $p	= $pattern;
		if ($p->isa('RDF::Query::Algebra::Sort')) {
			$context->{ skip_sort }++;
			$order	= $p->_as_sparql_order_exprs( $context, $indent );
			$p	= $p->pattern
		}
		if ($p->isa('RDF::Query::Algebra::Filter')) {
			$context->{ skip_filter }++;
			$having	= $p->expr->as_sparql( $context, $indent );
			$p		= $p->pattern;
		}
		$p	= ($p->patterns)[0] if ($p->isa('RDF::Query::Algebra::GroupGraphPattern') and scalar(@{[$p->patterns]}) == 1);
		if ($p->isa('RDF::Query::Algebra::Extend') and $p->pattern->isa('RDF::Query::Algebra::Aggregate')) {
			my $pp	= $p->pattern;
			$context->{ skip_extend }++;
			my $vlist	= $p->vars;
			foreach my $k (@$vlist) {
				if ($k->isa('RDF::Query::Expression::Alias')) {
					my $var		= $k->name;
					my $expr	= $k->expression;
					my $exprstr;
					if ($expr->isa('RDF::Query::Expression::Binary')) {
						$exprstr	= $expr->as_sparql( $context, $indent );
					} else {
						$exprstr	= $k->expression->name;
					}
					my $str		= "($exprstr AS ?$var)";
					$agg_projections{ '?' . $var }	= $str;
				} else {
					warn Dumper($k) . ' ';
				}
			}
			
			my @groups	= $pp->groupby;
			if (@groups) {
				$group	= join(' ', map { $_->as_sparql($context, $indent) } @groups);
			}
		}
	}
	
	if ($pattern->isa('RDF::Query::Algebra::Extend')) {
		my %seen;
		my $vlist	= $pattern->vars;
		foreach my $k (@$vlist) {
			if ($k->isa('RDF::Query::Expression::Alias')) {
				$seen{ '?' . $k->name }	= $k->as_sparql({}, '');
			} elsif ($k->isa('RDF::Query::Expression')) {
				push(@vars, $k->as_sparql({}, ''));
			} elsif ($k->isa('RDF::Query::Node::Variable')) {
				push(@vars, '?' . $k->name);
			} else {
				push(@vars, $k);
			}
		}
		@vars	= map { exists($seen{$_}) ? $seen{$_} : $_ } @vars;
		$vars	= join(' ', @vars);
		my $pp	= $pattern->pattern;
		if ($pp->isa('RDF::Query::Algebra::Aggregate')) {
			$_sparql	= $pp->pattern->as_sparql( $context, $indent );
			my @groups	= $pp->groupby;
			if (@groups) {
				$group	= join(' ', map { $_->as_sparql($context, $indent) } @groups);
			}
		} else {
			$_sparql	= $pp->as_sparql( $context, $indent );
		}
	} else {
		my $pvars	= join(' ', map { my $agg = $agg_projections{ "?$_" }; defined($agg) ? $agg : "?$_" } sort $self->pattern->referenced_variables);
		my $svars	= join(' ', map { my $agg = $agg_projections{ $_ }; defined($agg) ? $agg : $_ } sort @vars);
		$vars		= ($pvars eq $svars) ? '*' : join(' ', map { my $agg = $agg_projections{ $_ }; defined($agg) ? $agg : $_ } @vars);
		$_sparql	= $pattern->as_sparql( $context, $indent );
	}
	my $sparql	= sprintf("%s WHERE %s", $vars, $_sparql);
	if ($group) {
		$sparql	.= "\n${indent}GROUP BY $group";
	}
	if ($having) {
		$sparql	.= "\n${indent}HAVING $having";
	}
	if ($order) {
		$sparql	.= "\n${indent}ORDER BY $order";
	}
	return $sparql;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		variables	=> [ map { $_->as_hash } @{ $self->vars } ],
		pattern		=> $self->pattern->as_hash,
	};
}

=item C<< as_spin ( $model ) >>

Adds statements to the given model to represent this algebra object in the
SPARQL Inferencing Notation (L<http://www.spinrdf.org/>).

=cut

sub as_spin {
	my $self	= shift;
	my $model	= shift;
	my $spin	= RDF::Trine::Namespace->new('http://spinrdf.org/spin#');
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my $q		= RDF::Query::Node::Blank->new();
	my @nodes	= $self->pattern->as_spin( $model );
	
	$model->add_statement( RDF::Trine::Statement->new($q, $rdf->type, $spin->Select) );
	
	my @vars	= map { RDF::Query::Node::Blank->new( "variable_" . $_->name ) } @{ $self->vars };
	my $vlist	= $model->add_list( @vars );
	$model->add_statement( RDF::Trine::Statement->new($q, $spin->resultVariables, $vlist) );
	
	my $list	= $model->add_list( @nodes );
	$model->add_statement( RDF::Trine::Statement->new($q, $spin->where, $list) );
	return $q;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'PROJECT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= $self->pattern->referenced_variables;
	foreach my $v (@{ $self->vars }) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v->name);
		} else {
			push(@vars, $v->referenced_variables);
		}
	}
	return RDF::Query::_uniq(@vars);
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my $pattern	= $self->pattern->bind_variables( $bound );
	my $vars	= $self->vars;
	my @vars;
	foreach my $v (@$vars) {
		if (blessed($v) and $v->isa('RDF::Query::Node::Variable') and exists $bound->{ $v->name }) {
			push(@vars, $bound->{ $v->name });
		} else {
			push(@vars, $v);
		}
	}
	return $class->new( $pattern, \@vars );
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @vars;
#	push(@vars, $self->pattern->potentially_bound);
	foreach my $v (@{ $self->vars }) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v->name);
		} else {
			push(@vars, $v->potentially_bound);
		}
	}
	return RDF::Query::_uniq(@vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
