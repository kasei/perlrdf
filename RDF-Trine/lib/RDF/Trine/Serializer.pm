# RDF::Trine::Serializer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer - RDF Serializer class.

=head1 VERSION

This document describes RDF::Trine::Serializer version 0.112

=head1 SYNOPSIS

 use RDF::Trine::Serializer;

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

our ($VERSION);
BEGIN {
	$VERSION	= '0.112';
}

use LWP::UserAgent;
use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::RDFXML;
use RDF::Trine::Serializer::RDFJSON;

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
