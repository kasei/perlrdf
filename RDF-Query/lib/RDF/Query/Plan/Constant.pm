# RDF::Query::Plan::Constant
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Constant - Executable query plan for Constants.

=head1 VERSION

This document describes RDF::Query::Plan::Constant version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Constant;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( @variable_bindings ) >>

=cut

sub new {
	my $class	= shift;
	my @binds	= @_;
	my $self	= $class->SUPER::new( \@binds );
	$self->[0]{referenced_variables}	= [ keys %{ $binds[0] } ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "CONSTANT plan can't be executed while already open";
	}
	
	$self->[0]{'index'}	= 0;
	$self->state( $self->OPEN );
	$self;
}

=item C<< bindings >>

Returns a list of the variable bindings for this constant result set.

=cut

sub bindings {
	my $self	= shift;
	my $binds	= $self->[1] || [];
	return @$binds;
}

=item C<< is_unit >>

Returns true if this constant result set is comprised of a single, empty variable binding.

=cut

sub is_unit {
	my $self	= shift;
	my @binds	= $self->bindings;
	return 0 unless scalar(@binds) == 1;
	my @keys	= keys %{ $binds[0] };
	return not(scalar(@keys));
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open CONSTANT";
	}
	my $binds	= $self->[1];
	if ($self->[0]{'index'} > $#{ $binds }) {
		return;
	}
	my $row	= $binds->[ $self->[0]{'index'}++ ];
	if ($row) {
		my $bindings	= RDF::Query::VariableBindings->new( $row );
		if (my $d = $self->delegate) {
			$d->log_result( $self, $bindings );
		}
		return $bindings;
	} else {
		return;
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open CONSTANT";
	}
	delete $self->[0]{'index'};
	$self->SUPER::close();
}

=item C<< size >>

=cut

sub size {
	my $self	= shift;
	return scalar( @{ $self->[1] } );
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	# XXX could check constant data to determine if it's unique
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	# XXX could check constant data to determine if it's ordered
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'table';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(*V);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $binds	= $self->[1];
	return @$binds;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
