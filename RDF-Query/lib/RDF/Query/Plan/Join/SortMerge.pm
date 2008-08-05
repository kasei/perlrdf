# RDF::Query::Plan::Join::SortMerge
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join::SortMerge - Executable query plan for sort-merge joins.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join::SortMerge;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join);

use Scalar::Util qw(blessed);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( $lhs, $rhs ) >>

=cut

sub new {
	my $class	= shift;
	my ($lhs, $rhs)	= @_;
	my $self	= $class->SUPER::new( $lhs, $rhs );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute;

=item C<< next >>

=cut

sub next;

=item C<< close >>

=cut

sub close;

=item C<< lhs >>

Returns the left-hand-side plan to the join.

=cut

sub lhs {
	my $self	= shift;
	return $self->[1];
}

=item C<< rhs >>

Returns the right-hand-side plan to the join.

=cut

sub rhs {
	my $self	= shift;
	return $self->[2];
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
