# RDF::Query::Plan::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Project - Executable query plan for Projects.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Project;

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
