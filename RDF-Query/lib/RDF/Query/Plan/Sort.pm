# RDF::Query::Plan::Sort
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Sort - Executable query plan for Sorts.

=head1 VERSION

This document describes RDF::Query::Plan::Sort version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Sort;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################


=item C<< new ( $pattern, [ $expr1, $rev1 ], ... ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my @exprs	= @_;
	foreach my $e (@exprs) {
		$e->[1]	||= 0;
	}
	my $self	= $class->SUPER::new( $plan, \@exprs );
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
		throw RDF::Query::Error::ExecutionError -text => "SORT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.sort");
	$l->trace("executing sort");
	if ($plan->state == $self->OPEN) {
		my $exprs	= $self->[2];
		my @rows	= $plan->get_all;
		if ($l->is_trace) {
			$l->trace("sorting result list:");
			$l->trace("- $_") foreach (@rows);
		}
		my $query	= $context->query;
		
		use sort 'stable';
		my @sorted	= sort { _cmp_rows( $context, $exprs, $a, $b ) } @rows;
		if ($l->is_trace) {
			$l->trace("sorted list:");
			$l->trace("- $_") foreach (@sorted);
		}
		$self->[0]{rows}	= \@sorted;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in distinct";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open SORT";
	}
	my $bindings	= shift(@{ $self->[0]{rows} });
	if (my $d = $self->delegate) {
		$d->log_result( $self, $bindings );
	}
	return $bindings;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open SORT";
	}
	delete $self->[0]{rows};
	$self->[1]->close();
	$self->SUPER::close();
}

sub _cmp_rows {
	my $context	= shift;
	my $exprs	= shift;
	my $a		= shift;
	my $b		= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.sort");
	my $query	= $context->query || 'RDF::Query';
	my $bridge	= $context->model;
	
	no warnings 'numeric';
	no warnings 'uninitialized';
	foreach my $data (@$exprs) {
		my ($expr, $rev)	= @$data;
		my $a_val	= $query->var_or_expr_value( $a, $expr, $context );
		my $b_val	= $query->var_or_expr_value( $b, $expr, $context );
		local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
		$l->trace("comparing $a_val <=> $b_val");
		my $cmp		= $a_val <=> $b_val;
		if ($cmp != 0) {
			if ($rev) {
				$cmp	*= -1;
			}
			$l->trace("==> $cmp");
			return $cmp;
		} else {
		}
	}
	$l->trace("==> 0");
	return 0;
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be sorted.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	return $self->pattern->distinct;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	my $sort	= $self->[2];
	
	return [ map { [ $_->[0], ($_->[1] ? 'DESC' : 'ASC') ] } @$sort ];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'order';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P *\wE);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $exprs	= $self->[2];
	return ($self->pattern, map { [ ($_->[1] == 0 ? 'asc' : 'desc'), $_->[0] ] } @$exprs);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	my $expr	= join(' ', map { $_->sse( {}, "" ) } @{ $self->[2] });
	$g->add_node( "$self", label => "Sort ($expr)" . $self->graph_labels );
	$g->add_edge( "$self", $c );
	return "$self";
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
	$string		.= "${indent}${s}sory by:\n";
	my $exprs	= $self->[2];
	foreach my $e (@$exprs) {
		my $dir		= ($e->[1] == 0 ? 'asc  ' : 'desc ');
		$string		.= "${indent}${s}${s}${dir}" . $e->[0] . "\n";
	}
	$string		.= $self->pattern->explain( $s, $count+1 );
	return $string;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
