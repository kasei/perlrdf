# RDF::Query::Plan::Join
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join - Join query plan base class.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Query::ExecutionContext;

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
