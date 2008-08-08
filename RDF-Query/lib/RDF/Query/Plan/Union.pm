# RDF::Query::Plan::Union
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Union - Executable query plan for unions.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Union;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( $lhs, $rhs ) >>

=cut

sub new {
	my $class	= shift;
	my ($lhs, $rhs)	= @_;
	my $self	= $class->SUPER::new( [ $lhs, $rhs ] );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "BGP plan can't be executed while already open";
	}
	
	my $iter	= $self->[1][0];
	$iter->execute( $context );
	
	if ($iter->state == $self->OPEN) {
		$self->[0]{iter}	= $iter;
		$self->[0]{idx}		= 0;
		$self->[0]{context}	= $context;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open BGP";
	}
	my $iter	= $self->[0]{iter};
	my $row		= $iter->next;
	if ($row) {
		return $row;
	} else {
		return undef unless ($self->[0]{idx} < $#{ $self->[1] });
		$iter->close();
		my $iter	= $self->[1][ ++$self->[0]{idx} ];
		$iter->execute( $self->[0]{context} );
		if ($iter->state == $self->OPEN) {
			$self->[0]{iter}	= $iter;
			return $self->next;
		} else {
			throw RDF::Query::Error::ExecutionError -text => "execute() on RHS of UNION failed during next()";
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open BGP";
	}
	$self->[0]{iter}->close();
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return [];
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
