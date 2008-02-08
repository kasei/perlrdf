# RDF::Query::BloomFilter
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Bloom Filter implementation

=head1 METHODS

=over 4

=cut

package RDF::Query::BloomFilter;

BEGIN {
	our $VERSION	= '2.000';
}

use strict;
use warnings;

use Bloom::Filter;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
