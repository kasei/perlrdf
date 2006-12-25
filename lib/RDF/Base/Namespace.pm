# RDF::Base::Namespace
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Namespace - Shortcut syntax for constructing URI node objects.

=head1 VERSION

This document describes RDF::Base::Namespace version 0.0.1

=head1 SYNOPSIS

    use RDF::Base::Namespace;
    my $foaf = RDF::Base::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
    my $uri = $foaf->homepage;
    print $uri->as_string; # '[http://xmlns.com/foaf/0.1/homepage]'

=head1 DESCRIPTION

This module provides an abbreviated syntax for creating RDF::Redland::Node objects
for URIs sharing common namespaces. The module provides a constructor for creating
namespace objects which may be used for constructing Node objects. Calling any
method (other than 'import', 'new', 'uri' or 'AUTOLOAD') on the namespace object
will return a RDF::Redland::Node object representing the URI of the method name
appended to the namespace.

=cut

package RDF::Base::Namespace;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
use base qw(XML::Namespace);

use Carp;
use RDF::Base::Node::Resource;

=head1 METHODS

=over 4

=item C<uri>

Returns the URI node object for the namespace, with an optional path argument
added to the end of it.

=cut

sub uri {
	my $self	= shift;
	my $uri		= $self->SUPER::uri( @_ );
	return RDF::Base::Node::Resource->new( uri => $uri );
}


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


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

