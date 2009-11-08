# RDF::Trine
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trine - An RDF Framework for Perl.

=head1 VERSION

This document describes RDF::Trine version 0.111

=head1 SYNOPSIS

  use RDF::Trine;

=head1 DESCRIPTION

RDF::Trine provides an RDF framework with an emphasis on extensibility, API
stability, and the presence of a test suite. The package consists of several
components:

=over 4

=item * RDF::Trine::Model - RDF model providing access to a triple store.

=item * RDF::Trine::Parser - Native RDF parsers (currently RDF/XML and Turtle only).

=item * RDF::Trine::Store::DBI - A triple store for MySQL and SQLite, based on the Redland schema.

=item * RDF::Trine::Iterator - Iterator classes for variable bindings and RDF statements, used by RDF::Trine::Store, RDF::Trine::Model, and RDF::Query.

=item * RDF::Trine::Namespace - A convenience class for easily constructing RDF node objects from URI namespaces.

=back

=head1 METHODS

=over 4

=cut

package RDF::Trine;

use strict;
use warnings;
no warnings 'redefine';

our ($debug, $VERSION);
BEGIN {
	$debug		= 0;
	$VERSION	= '0.111';
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

use RDF::Trine::Parser;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Iterator;
use RDF::Trine::Store;
use RDF::Trine::Store::DBI;
use RDF::Trine::Error;
use RDF::Trine::Model;

sub _uniq {
	my %seen;
	my @data;
	foreach (@_) {
		push(@data, $_) unless ($seen{ $_ }++);
	}
	return @data;
}

1; # Magic true value required at end of module
__END__

=back

=head1 DEPENDENCIES

L<Data::UUID>
L<DBI>
L<DBD::SQLite>
L<Digest::MD5>
L<Error>
L<JSON>
L<LWP::UserAgent>
L<List::Util>
L<Log::Log4perl>
L<Math::BigInt>
L<Scalar::Util>
L<Text::Table>
L<Time::HiRes>
L<Unicode::Escape>
L<Unicode::String>
L<URI>
L<XML::CommonNS>
L<XML::Namespace>
L<XML::SAX>
L<XML::LibXML::SAX>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<< <gwilliams@cpan.org> >>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

