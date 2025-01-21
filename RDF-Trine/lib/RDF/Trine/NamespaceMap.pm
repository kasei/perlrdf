# RDF::Trine::NamespaceMap
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Trine::NamespaceMap - Collection of Namespaces

=head1 VERSION

This document describes RDF::Trine::NamespaceMap version 1.007

=head1 SYNOPSIS

    use RDF::Trine::NamespaceMap;
    my $map = RDF::Trine::NamespaceMap->new( \%namespaces );
    $serializer->serialize_model_to_string( $model, namespaces => $map );

    $map->add_mapping( foaf => 'http://xmlns.com/foaf/0.1/' );
    my $foaf_namespace = $map->foaf;
    my $foaf_person    = $map->foaf('Person');

=head1 DESCRIPTION

This module provides an object to manage multiple namespaces for
creating L<RDF::Trine::Node::Resource> objects and for serializing.

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
	$VERSION	= '1.007';
}

######################################################################

=item C<< new ( [ \%namespaces ] ) >>

Returns a new namespace map object. You can pass a hash reference with
mappings from local names to namespace URIs (given as string or
L<RDF::Trine::Node::Resource>).

=cut

sub new {
	my $class	= shift;
	my $map		= shift || {};
	my $self	= bless( {}, $class );
	foreach my $name ( keys %$map ) {
		$self->add_mapping( $name => $map->{$name} );
	}
	return $self;
}

=item C<< add_mapping ( $name => $uri ) >>

Adds a new namespace to the map. The namespace URI can be passed
as string or some object, that provides an uri_value method.

=cut

sub add_mapping {
	my $self	= shift;
	my $name	= shift;
	if ($name =~ /^(new|uri|can|isa|VERSION|DOES)$/) {
		# reserved names
		throw RDF::Trine::Error::MethodInvocationError -text => "Cannot use reserved name '$name' as a namespace prefix";
	}
	
	my $ns		= shift;
	foreach (qw(1 2)) {
		# loop twice because the first call to C<<uri_value>> might return a
		# RDF::Trine::Namespace. Calling C<<uri_value>> on the namespace object
		# will then return a URI string value.
		if (blessed($ns) and $ns->can('uri_value')) {
			$ns = $ns->uri_value;
		}
	}
	$ns	= RDF::Trine::Namespace->new( $ns );
	$self->{ $name }	= $ns;
}

=item C<< remove_mapping ( $name ) >>

Removes a namespace from the map.

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

=item C<< uri ( $prefixed_name ) >>

Returns a URI (as L<RDF::Trine::Node::Resource>) for an abbreviated
string such as 'foaf:Person'.

=cut

sub uri {
	my $self	= shift;
	my $abbr	= shift;
	my $ns;
	my $local	= "";
	if ($abbr =~ m/^([^:]*):(.*)$/) {
		$ns	= $self->{ $1 };
		$local	= $2;
	} else {
		$ns	= $self->{ $abbr };
	}
	return unless (blessed($ns));
	if ($local ne '') {
		return $ns->$local();
	} else {
		return $ns->uri_value;
	}
}

=item prefix_for C<< uri ($uri) >>

Returns the associated prefix (or potentially multiple prefixes, in
list context) for the given URI.

=cut

sub prefix_for {
    my ($self, $uri) = @_;
    $uri = $uri->value if ref $uri;

    my @candidates;
    while (my ($k, $v) = each %$self) {
        my $vuri = $v->uri->uri_value;
        # the input should always be longer than the namespace
        next if length $vuri > length $uri;

        # candidate namespace must match exactly
        my $cns = substr($uri, 0, length $vuri);
        push @candidates, $k if $cns eq $vuri;
    }

    # make sure this behaves correctly when empty
    return unless @candidates;

    # if this returns more than one prefix, take the
    # shortest/lexically lowest one.
    @candidates = sort @candidates;

    return wantarray ? @candidates : $candidates[0];
}

=item abbreviate C<< uri ($uri) >>

Complement to L</namespace_uri>. Returns the given URI in C<foo:bar>
format or C<undef> if it wasn't matched, therefore the idiom

    my $str = $nsmap->abbreviate($uri_node) || $uri_node->uri_value;

may be useful for certain serialization tasks.

=cut

sub abbreviate {
    my ($self, $uri) = @_;
    $uri = $uri->uri_value if ref $uri;
    my $prefix = $self->prefix_for($uri);

    # XXX is this actually the most desirable behaviour?
    return unless defined $prefix;

    my $offset = length $self->namespace_uri($prefix)->uri->uri_value;

    return sprintf('%s:%s', $prefix, substr($uri, $offset));
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

=head1 WARNING

Avoid using the names 'can', 'isa', 'VERSION', and 'DOES' as namespace prefix,
because these names are defined as method for every Perl object by default.
The method names 'new' and 'uri' are also forbidden.

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
