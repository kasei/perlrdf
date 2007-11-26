# RDF::Namespace
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Namespace - Abbreviated syntax for constructing RDF node objects.

=head1 VERSION

This document describes RDF::Namespace version 0.0.1

=head1 SYNOPSIS

    use RDF::Namespace qw(rdf);
    my $foaf = RDF::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
    my $pred = $foaf->name;
    my $type = $rdf->type;
    print $pred->as_string; # '[http://xmlns.com/foaf/0.1/name]'

=head1 DESCRIPTION

This module provides an abbreviated syntax for creating RDF::Query::Node objects
for URIs sharing common namespaces. The module provides a constructor for creating
namespace objects which may be used for constructing Node objects. Calling any
method (other than 'import', 'new', 'uri' or 'AUTOLOAD') on the namespace object
will return a RDF::Query::Node object representing the URI of the method name
appended to the namespace.

=head1 METHODS

=over 4

=cut

package RDF::Namespace;

our $VERSION = '0.001';

use strict;
use warnings;

use base qw(XML::Namespace);

use Carp;
use RDF::Query::Node::Resource;
use XML::CommonNS 0.04 ();

sub import {
	my $class	= shift;
	if (@_) {
		$class->_install_namespaces( 1, @_ );
	}
}

sub _install_namespaces {
	my $class	= shift;
	my $level	= shift;
	my $pkg		= caller( $level );
	if (@_) {
		foreach my $name (@_) {
			my $uri	= XML::CommonNS->uri( uc($name) );
			my $ns	= __PACKAGE__->new( "$uri" );
			no strict 'refs';
			*{ "${pkg}::${name}" }	= \$ns;
		}
	}
}

=item C<uri>

Returns the URI node object for the namespace, with an optional path argument
added to the end of it.

=cut

sub uri {
	my $self	= shift;
	my $uri		= $self->SUPER::uri( @_ );
	return RDF::Query::Node::Resource->new( $uri );
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


=head1 COPYRIGHT

Copyright (c) 2006-2007 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

