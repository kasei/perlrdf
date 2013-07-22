# RDF::Query::Functions
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Functions - Standard Extension Functions

=head1 VERSION

This document describes RDF::Query::Functions version 2.910.

=head1 DESCRIPTION

This stub module simply loads all other modules named
C<< RDF::Query::Functions::* >>. Each of those modules
has an C<install> method that simply adds coderefs
to C<< %RDF::Query::functions >>.

=head1 METHODS

=over 4

=cut

package RDF::Query::Functions;

use strict;
use warnings;
no warnings 'redefine';

our $BLOOM_FILTER_LOADED;

use Scalar::Util qw(refaddr);
use Log::Log4perl;

use Module::Pluggable
	search_path => [ __PACKAGE__ ],
	require     => 1,
	inner       => 1,
	sub_name    => 'function_sets',
	;

######################################################################

our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions");
	$VERSION	= '2.910';
}

######################################################################

=item C<< install_function ( $uri, \&func ) >>

=item C<< install_function ( \@uris, \&func ) >>

Install the supplied CODE reference as the implementation for the given function URI(s).

=cut

sub install_function {
	my $class	= shift;
	while (@_) {
		my $uris	= shift;
		my $func	= shift;
		$RDF::Query::preferred_function_name{ refaddr($func) }	= ref($uris) ? $uris->[0] : $uris;
		foreach my $uri (ref($uris) ? @$uris : $uris) {
			$RDF::Query::functions{$uri}	= $func;
		}
	}
}

foreach my $function_set (__PACKAGE__->function_sets) {
	$function_set->install;
}

1;

__END__

=back

=head1 SEE ALSO

L<RDF::Query::Functions::SPARQL>,
L<RDF::Query::Functions::Xpath>,
L<RDF::Query::Functions::Jena>,
L<RDF::Query::Functions::Geo>,
L<RDF::Query::Functions::Kasei>.

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>,
 Toby Inkster <tobyink@cpan.org>.

=cut
