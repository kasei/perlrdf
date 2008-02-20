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

use base qw(Bloom::Filter);
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);

=item C<< from_bloom_filter ( $bf ) >>

Upgrades a Bloom::Filter object to a RDF::Query::BloomFilter object.

=cut

sub from_bloom_filter {
	my $class	= shift;
	my $filter	= shift;
	return bless($filter, $class);
}

=item C<< add ( @nodes ) >>

Adds the (string representation of the) given RDF::Query::Nodes to the filter.

=cut

sub add {
	my $self	= shift;
	foreach my $node (@_) {
		$self->SUPER::add( $node->as_string );
	}
}

=item C<< check ( $node ) >>

Returns true if the (string representation of the) given RDF::Query::Node object
is in the filter. Otherwise, returns false with high probability.

=cut

sub check {
	my $self	= shift;
	my $node	= shift;
	return $self->SUPER::check( $node->as_string );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
