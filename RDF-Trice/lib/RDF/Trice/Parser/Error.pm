=head1 NAME

RDF::Trice::Parser::Error - Error classes for RDF::Trice::Parser.

=head1 VERSION

This document describes RDF::Trice::Parser::Error version 1.001

=head1 SYNOPSIS

 use RDF::Trice::Parser::Error qw(:try);

=head1 DESCRIPTION

RDF::Trice::Parser::Error provides an class hierarchy of errors that other RDF::Trice::Parser
classes may throw using the L<Error|Error> API. See L<Error> for more information.

=head1 REQUIRES

L<Error|Error>

=cut

package RDF::Trice::Parser::Error;

use strict;
use warnings;
use Carp qw(carp croak confess);

use base qw(Error);

######################################################################

our ($REVISION, $VERSION, $debug);
BEGIN {
	$debug		= 0;
	$REVISION	= do { my $REV = (qw$Revision: 127 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= 1.001;
}

######################################################################

package RDF::Trice::Parser::Error::ValueError;

use base qw(RDF::Trice::Parser::Error);

1;

__END__

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
