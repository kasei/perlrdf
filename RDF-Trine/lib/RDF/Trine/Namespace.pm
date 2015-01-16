# RDF::Trine::Namespace
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trine::Namespace - Abbreviated syntax for constructing RDF node objects

=head1 VERSION

This document describes RDF::Trine::Namespace version 1.012

=head1 SYNOPSIS

    use RDF::Trine::Namespace qw(rdf);
    my $foaf = RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
    my $pred = $foaf->name;
    my $type = $rdf->type;
    print $pred->as_string; # '[http://xmlns.com/foaf/0.1/name]'

=head1 DESCRIPTION

This module provides an abbreviated syntax for creating RDF::Trine::Node objects
for URIs sharing common namespaces. The module provides a constructor for creating
namespace objects which may be used for constructing Node objects. Calling any
method (other than 'import', 'new', 'uri' or 'AUTOLOAD') on the namespace object
will return a RDF::Trine::Node object representing the URI of the method name
appended to the namespace.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Namespace;

use strict;
use warnings;
no warnings 'redefine';
use base qw(XML::Namespace);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################


use Carp;
use RDF::Trine::Node::Resource;
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
	foreach my $name (@_) {
		my $uri	= (uc($name) eq 'XSD')
			? XML::NamespaceFactory->new('http://www.w3.org/2001/XMLSchema#')
			: XML::CommonNS->uri( uc($name) );
		my $ns	= $class->new( "$uri" );
		no strict 'refs';	## no critic (ProhibitNoStrict)
		*{ "${pkg}::${name}" }	= \$ns;
	}
}

=item C<uri>

Returns the URI node object for the namespace, with an optional path argument
added to the end of it.

=cut

sub uri {
	my $self	= shift;
	my $local	= shift;
	unless (defined($local)) {
		$local	= '';
	}
	
	# we should just call $self->SUPER::uri($local) here, but there's a bug in
	# XML::Namespace 0.2 that assumes $local eq '' if $local is defined but false (e.g. '0')
	my $uri		= $self->SUPER::uri() . $local;	
	return RDF::Trine::Node::Resource->new( $uri );
}

=item C<< uri_value >>

Returns the URI/IRI value of this namespace.

=cut

sub uri_value {
	my $self	= shift;
	return $self->uri();
}

1; # Magic true value required at end of module
__END__

=back

=head1 DEPENDENCIES

L<XML::Namespace>

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
