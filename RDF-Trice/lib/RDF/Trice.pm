# RDF::Trice
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trice - An RDF Framework for Perl.

=head1 VERSION

This document describes RDF::Trice version 0.0.1

=head1 SYNOPSIS

  use RDF::Trice;

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trice;

BEGIN {
	our $VERSION	= '1.000';
}

use RDF::Trice::Parser;
use RDF::Trice::Node;
use RDF::Trice::Statement;
use RDF::Trice::Namespace;
use RDF::Trice::Iterator;
use RDF::Trice::Store::DBI;
use RDF::Trice::Error;


1; # Magic true value required at end of module
__END__

=back

=head1 DEPENDENCIES

L<XML::Namespace>

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

