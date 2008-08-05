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

=item C<< new ( $bgp ) >>

=cut

sub new;

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($);

=item C<< next >>

=cut

sub next;

=item C<< close >>

=cut

sub close;

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
