=head1 NAME

RDF::Query::Functions::Kasei - RDF-Query-specific functions

=head1 VERSION

This document describes RDF::Query::Functions::Kasei version 2.918.

=head1 DESCRIPTION

Defines the following functions:

=over

=item * http://kasei.us/2007/09/functions/warn

=item * http://kasei.us/code/rdf-query/functions/bloom

=item * http://kasei.us/code/rdf-query/functions/bloom/filter

=back

=cut

package RDF::Query::Functions::Kasei;

use strict;
use warnings;
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.kasei");
	$VERSION	= '2.918';
}

use Data::Dumper;
use Scalar::Util qw(blessed reftype refaddr looks_like_number);

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install
{	
	RDF::Query::Functions->install_function(
		"http://kasei.us/2007/09/functions/warn",
		sub {
			my $query	= shift;
			my $value	= shift;
			my $func	= RDF::Query::Expression::Function->new( 'sparql:str', $value );
			
			my $string	= Dumper( $func->evaluate( undef, undef, {} ) );
			no warnings 'uninitialized';
			warn "FILTER VALUE: $string\n";
			return $value;
		}
	);
}


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
