# RDF::Trine
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trine - An RDF Framework for Perl.

=head1 VERSION

This document describes RDF::Trine version 0.103

=head1 SYNOPSIS

  use RDF::Trine;

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine;

use strict;
use warnings;
no warnings 'redefine';

BEGIN {
	our $VERSION	= '0.103';
}

use RDF::Trine::Parser;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Iterator;
use RDF::Trine::Store::DBI;
use RDF::Trine::Error;
use RDF::Trine::Model;


1; # Magic true value required at end of module
__END__

=back

=head1 DEPENDENCIES

L<Bloom::Filter>
L<Data::UUID>
L<DBI>
L<DBD::SQLite>
L<Digest::MD5>
L<Error>
L<JSON>
L<LWP::UserAgent>
L<List::MoreUtils>
L<List::Util>
L<Math::BigInt>
L<Scalar::Util>
L<Unicode::Escape>
L<URI>
L<XML::CommonNS>
L<XML::Namespace>
L<XML::Twig>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.

=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 COPYRIGHT

Copyright (c) 2006-2007 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

