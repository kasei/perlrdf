=head1 NAME

RDF::Endpoint::Error - Error classes for RDF::Endpoint.

=head1 SYNOPSIS

 use RDF::Endpoint::Error qw(:try);

=head1 DESCRIPTION

RDF::Endpoint::Error provides an class hierarchy of errors that other RDF::Endpoint
classes may throw using the L<Error|Error> API. See L<Error> for more information.

=head1 REQUIRES

L<Error|Error>

=cut

package RDF::Endpoint::Error;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use base qw(Error);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200';
}

######################################################################

package RDF::Endpoint::Error::MalformedQuery;

use base qw(RDF::Endpoint::Error);

package RDF::Endpoint::Error::InternalError;

use base qw(RDF::Endpoint::Error);

package RDF::Endpoint::Error::EncodingError;

use base qw(RDF::Endpoint::Error);


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
