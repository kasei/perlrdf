# RDF::Query::Plan::Sort
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Sort - Executable query plan for Sorts.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Sort;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $pattern, [ $expr1, $rev1 ], ... ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my @exprs	= @_;
	my $self	= $class->SUPER::new( $plan, \@exprs );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "SORT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );
	
	if ($plan->state == $self->OPEN) {
		my $exprs	= $self->[2];
		my @rows	= $plan->get_all;
		my $query	= $context->query;
		
		use sort 'stable';
		@rows		= sort { _cmp_rows( $context, $exprs, $a, $b ) } @rows;
		$self->[3]{rows}	= \@rows;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in distinct";
	}
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open SORT";
	}
	return shift(@{ $self->[3]{rows} });
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open SORT";
	}
	delete $self->[3]{rows};
	$self->[1]->close();
	$self->SUPER::close();
}

sub _cmp_rows {
	my $context	= shift;
	my $exprs	= shift;
	my $a		= shift;
	my $b		= shift;
	
	my $query	= $context->query || 'RDF::Query';
	my $bridge	= $context->model;
	
	no warnings 'numeric';
	foreach my $data (@$exprs) {
		my ($expr, $rev)	= @$data;
		my $a_val	= $query->var_or_expr_value( $bridge, $a, $expr );
		my $b_val	= $query->var_or_expr_value( $bridge, $b, $expr );
		local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
		my $cmp		= $a_val <=> $b_val;
		if ($cmp != 0) {
			if ($rev) {
				$cmp	*= -1;
			}
			return $cmp;
		} else {
		}
	}
	return 0;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
