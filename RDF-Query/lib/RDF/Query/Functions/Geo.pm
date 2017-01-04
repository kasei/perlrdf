=head1 NAME

RDF::Query::Functions::Geo - Geographic extension functions

=head1 VERSION

This document describes RDF::Query::Functions::Geo version 2.918.

=head1 DESCRIPTION

Defines the following function:

=over

=item * java:com.ldodds.sparql.Distance

=back

=cut

package RDF::Query::Functions::Geo;

use strict;
use warnings;
use Scalar::Util qw(blessed reftype refaddr looks_like_number);
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.geo");
	$VERSION	= '2.918';
}

our $GEO_DISTANCE_LOADED;
BEGIN {
	$GEO_DISTANCE_LOADED	= do {
		eval {
			require Geo::Distance;
		};
		($@) ? 0 : 1;
	};
}

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install {
	RDF::Query::Functions->install_function(
		"java:com.ldodds.sparql.Distance",
		sub {
			# http://xmlarmyknife.com/blog/archives/000281.html
			my $query	= shift;
			my ($lat1, $lon1, $lat2, $lon2);
			
			unless ($GEO_DISTANCE_LOADED) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute distance because Geo::Distance is not available" );
			}
	
			my $geo		= ref($query)
						? ($query->{_query_cache}{'java:com.ldodds.sparql.Distance'}{_geo_dist_obj} ||= new Geo::Distance)
						: new Geo::Distance;
			if (2 == @_) {
				my ($point1, $point2)	= map { $_->literal_value } splice(@_,0,2);
				($lat1, $lon1)	= split(/ /, $point1);
				($lat2, $lon2)	= split(/ /, $point2);
			} else {
				($lat1, $lon1, $lat2, $lon2)	= map { $_->literal_value } splice(@_,0,4);
			}
			
			my $dist	= $geo->distance(
							'kilometer',
							$lon1,
							$lat1,
							$lon2,
							$lat2,
						);
		#	warn "ldodds:Distance => $dist\n";
			return RDF::Query::Node::Literal->new("$dist", undef, 'http://www.w3.org/2001/XMLSchema#float');
		}
	);
}

1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
