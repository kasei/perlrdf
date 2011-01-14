# RDF::Trine::NamespaceMap
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trine::NamespaceMap - Collection of Namespaces

=head1 VERSION

This document describes RDF::Trine::NamespaceMap version 0.132

=head1 SYNOPSIS

    use RDF::Trine::NamespaceMap;
    my $map = RDF::Trine::NamespaceMap->new( \%namespaces );
    $serializer->serialize_model_to_string( $model, namespaces => $map );

=head1 DESCRIPTION

TODO

=head1 METHODS

=over 4

=cut

package RDF::Trine::NamespaceMap;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);
use Data::Dumper;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.132';
}

######################################################################

=item C<< new ( \%namespaces ) >>

Returns a new namespace map object.

=cut

sub new {
	my $class	= shift;
	my $map		= shift || {};
	return bless( { %$map }, $class );
}

=item C<< add_mapping ( $name => $uri ) >>

Adds a new namespace to the map.

=cut

sub add_mapping {
	my $self	= shift;
	my $name	= shift;
	my $ns		= shift;
	unless (blessed($ns)) {
		$ns	= RDF::Trine::Node::Resource->new( $ns );
	}
	$self->{ $name }	= $ns;
}

=item C<< remove_mapping ( $name ) >>

=cut

sub remove_mapping {
	my $self	= shift;
	my $name	= shift;
	delete $self->{ $name };
}

=item C<< namespace_uri ( $name ) >>

Returns the namespace object (if any) associated with the given name.

=cut

sub namespace_uri {
	my $self	= shift;
	my $name	= shift;
	return $self->{ $name };
}

sub AUTOLOAD {
	my $self	= shift;
	our $AUTOLOAD;
	return if ($AUTOLOAD =~ /:DESTROY$/);
	my ($name)	= ($AUTOLOAD =~ m/^.*:(.*)$/);
	my $ns		= $self->{ $name };
	return unless (blessed($ns));
	if (scalar(@_)) {
		my $local	= shift(@_);
		return $ns->$local( @_ );
	} else {
		return $ns;
	}
}

1; # Magic true value required at end of module
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to
C<< <gwilliams@cpan.org> >>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
