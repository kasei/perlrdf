# RDF::Trine::Serializer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer - RDF Serializer class.

=head1 VERSION

This document describes RDF::Trine::Serializer version 0.114_04

=head1 SYNOPSIS

 use RDF::Trine::Serializer;

=head1 DESCRIPTION

The RDF::Trine::Serializer class provides an API for serializing RDF graphs
(via both model objects and graph iterators) to strings and files.

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
	$VERSION	= '0.114_04';
}

use LWP::UserAgent;

use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::NTriples::Canonical;
use RDF::Trine::Serializer::RDFXML;
use RDF::Trine::Serializer::RDFJSON;
use RDF::Trine::Serializer::Turtle;

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
