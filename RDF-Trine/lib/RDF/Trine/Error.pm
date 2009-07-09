# RDF::Trine::Error
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Error - Error classes for RDF::Trine.

=head1 VERSION

This document describes RDF::Trine::Error version 0.111_01

=head1 SYNOPSIS

 use RDF::Trine::Error qw(:try);

=head1 DESCRIPTION

RDF::Trine::Error provides an class hierarchy of errors that other RDF::Trine
classes may throw using the L<Error|Error> API. See L<Error> for more information.

=head1 REQUIRES

L<Error|Error>

=cut

package RDF::Trine::Error;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use base qw(Error);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.111_01';
}

######################################################################

package RDF::Trine::Error::CompilationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::QuerySyntaxError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::MethodInvocationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::SerializationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::DatabaseError;

use base qw(RDF::Trine::Error);


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
