# RDF::Query::Plan::Filter
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Filter - Executable query plan for Filters.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Filter;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

=item C<< new ( $plan, $expr ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $expr	= shift;
	my $self	= $class->SUPER::new( $plan, $expr );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "FILTER plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );

	if ($plan->state == $self->OPEN) {
		$self->state( $self->OPEN );
		my $expr	= $self->[2];
		my $bool	= RDF::Query::Node::Resource->new( "sparql:ebv" );
		my $filter	= RDF::Query::Expression::Function->new( $bool, $expr );
		my $query	= $context->query;
		my $bridge	= $context->model;
		$self->[0]{filter}	= sub {
			my $row		= shift;
			my $bool	= 0;
			eval {
				my $value	= $filter->evaluate( $query, $bridge, $row );
				$bool	= ($value->literal_value eq 'true') ? 1 : 0;
			};
			return $bool;
		};
	} else {
		warn "could not execute plan in filter";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open FILTER";
	}
	my $plan	= $self->[1];
	my $filter	= $self->[0]{filter};
	while (1) {
		my $row	= $plan->next;
		return undef unless ($row);
		if ($filter->( $row )) {
			return $row;
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open FILTER";
	}
	delete $self->[0]{filter};
	$self->[1]->close();
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be filtered.

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
	return $self->pattern->ordered;
}

=item C<< sse >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf("(filter\n${indent}${more}%s\n${indent}${more}%s\n${indent})", $self->[2]->sse( $context, "${indent}${more}" ), $self->pattern->sse( $context, "${indent}${more}" ));
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
