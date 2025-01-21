# RDF::Trine::Node::Resource
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Resource - RDF Node class for resources

=head1 VERSION

This document describes RDF::Trine::Node::Resource version 1.002

=cut

package RDF::Trine::Node::Resource;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use URI 1.52;
use Encode;
use Data::Dumper;
use Scalar::Util qw(blessed reftype refaddr);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, %sse, %ntriples);
BEGIN {
	$VERSION	= '1.002';
}

######################################################################

use overload	'""'	=> sub { $_[0]->sse },
			;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Node> class.

=over 4

=cut

=item C<new ( $iri, [ $base_uri ] )>

Returns a new Resource structure.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	my $base_uri	= shift;
	
	unless (defined($uri)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Resource constructor called with an undefined value";
	}
	
	if (defined($base_uri)) {
		$base_uri	= (blessed($base_uri) and $base_uri->isa('RDF::Trine::Node::Resource')) ? $base_uri->uri_value : "$base_uri";
		$uri	= URI->new_abs($uri, $base_uri)->as_iri;
	}
	
	if ($uri eq &RDF::Trine::NIL_GRAPH) {
		return RDF::Trine::Node::Nil->new();
	}
	return bless( [ 'URI', $uri ], $class );
}

=item C<< uri_value >>

Returns the URI/IRI value of this resource.

=cut

sub uri_value {
	my $self	= shift;
	return $self->[1];
}

=item C<< value >>

Returns the URI/IRI value.

=cut

sub value {
	my $self	= shift;
	return $self->uri_value;
}

=item C<< uri ( $uri ) >>

Returns the URI value of this resource, optionally updating the URI.

=cut

sub uri {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
		delete $sse{ refaddr($self) };
		delete $ntriples{ refaddr($self) };
	}
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this resource.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	if ($context) {
		my $uri		= $self->uri_value;
		my $ns		= $context->{namespaces} || {};
		my %ns		= %$ns;
		foreach my $k (keys %ns) {
			my $v	= $ns{ $k };
			if (index($uri, $v) == 0) {
				my $qname	= join(':', $k, substr($uri, length($v)));
				return $qname;
			}
		}
	}
	
	my $ra	= refaddr($self);
	if ($sse{ $ra }) {
		return $sse{ $ra };
	} else {
		my $string	= URI->new( encode_utf8($self->uri_value) )->canonical;
		my $sse		= '<' . $string . '>';
		$sse{ $ra }	= $sse;
		return $sse;
	}
	
# 	my $string	= $uri;
# 	my $escaped	= $self->_unicode_escape( $string );
# 	return '<' . $escaped . '>';
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return '<' . $self->uri_value . '>';
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	my $self	= shift;
	my $context	= shift;
	my $ra		= refaddr($self);
	if ($ntriples{ $ra }) {
		return $ntriples{ $ra };
	} else {
		my $string		= URI->new( encode_utf8($self->uri_value) )->canonical;
		my $ntriples	= '<' . $string . '>';
		$ntriples{ $ra }	= $ntriples;
		return $ntriples;
	}
	
# 	my $uri		= $self->uri_value;
# 	my $string	= $uri;
# 	$string	=~ s/\\/\\\\/g;
# 	my $escaped	= $self->_unicode_escape( $string );
# 	$escaped	=~ s/"/\\"/g;
# 	$escaped	=~ s/\n/\\n/g;
# 	$escaped	=~ s/\r/\\r/g;
# 	$escaped	=~ s/\t/\\t/g;
# 	return '<' . $escaped . '>';
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'URI';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless defined($node);
	return 1 if (refaddr($self) == refaddr($node));
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node::Resource'));
	return ($self->[1] eq $node->[1]);
}

# called to compare two nodes of the same type
sub _compare {
	my $a	= shift;
	my $b	= shift;
	return ($a->uri_value cmp $b->uri_value);
}

=item C<< qname >>

If the IRI can be split into a namespace and local part for construction of a
QName, returns a list containing these two parts. Otherwise throws an exception.

=cut

sub qname {
	my $p		= shift;
	my $uri		= $p->uri_value;

	our $r_PN_CHARS_BASE	||= qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
	our $r_PN_CHARS_U		||= qr/(_|${r_PN_CHARS_BASE})/;
	our $r_PN_CHARS			||= qr/${r_PN_CHARS_U}|-|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]/;
	our $r_PN_LOCAL			||= qr/((${r_PN_CHARS_U})((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
	if ($uri =~ m/${r_PN_LOCAL}$/) {
		my $ln	= $1;
		my $ns	= substr($uri, 0, length($uri)-length($ln));
		return ($ns, $ln);
	} else {
		throw RDF::Trine::Error -text => "Can't turn IRI $uri into a QName.";
	}
}

sub DESTROY {
	my $self	= shift;
	delete $sse{ refaddr($self) };
	delete $ntriples{ refaddr($self) };
}

1;

__END__

=back

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
