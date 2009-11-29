# RDF::Trine::Node
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node - Base class for RDF Nodes

=head1 VERSION

This document describes RDF::Trine::Node version 0.112_01

=head1 METHODS

=over 4

=cut

package RDF::Trine::Node;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION);
BEGIN {
	$VERSION	= '0.112_01';
}

use Scalar::Util qw(blessed);
use Unicode::String;

use RDF::Trine::Node::Blank;
use RDF::Trine::Node::Literal;
use RDF::Trine::Node::Resource;
use RDF::Trine::Node::Variable;

=item C<< is_node >>

Returns true if this object is a RDF node, false otherwise.

=cut

sub is_node {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node'));
}

=item C<< is_blank >>

Returns true if this RDF node is a blank node, false otherwise.

=cut

sub is_blank {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Blank'));
}

=item C<< is_resource >>

Returns true if this RDF node is a resource, false otherwise.

=cut

sub is_resource {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Resource'));
}

=item C<< is_literal >>

Returns true if this RDF node is a literal, false otherwise.

=cut

sub is_literal {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Literal'));
}

=item C<< is_variable >>

Returns true if this RDF node is a variable, false otherwise.

=cut

sub is_variable {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Variable'));
}

=item C<< as_string >>

Returns the node in a string form.

=cut

sub as_string {
	my $self	= shift;
	return $self->sse;
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	return $_[0]->sse;
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	return 0;
}

=item C<< from_sse ( $string, $context ) >>

Parses the supplied SSE-encoded string and returns a RDF::Trine::Node object.

=cut

my $r_PN_CHARS_BASE		= qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
my $r_PN_CHARS_U		= qr/(_|${r_PN_CHARS_BASE})/;
my $r_VARNAME			= qr/((${r_PN_CHARS_U}|[0-9])(${r_PN_CHARS_U}|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}])*)/;
sub from_sse {
	my $class	= shift;
	my $context	= $_[1];
	for ($_[0]) {
		if (my ($iri) = m/^<([^>]+)>/o) {
			s/^<([^>]+)>\s*//;
			return RDF::Trine::Node::Resource->new( $iri );
		} elsif (my ($lit) = m/^"(([^"\\]+|\\([\\"nt]))+)"/o) {
			my @args;
			s/^"(([^"\\]+|\\([\\"nt]))+)"//;
			if (my ($lang) = m/[@](\S+)/) {
				s/[@](\S+)\s*//;
				$args[0]	= $lang;
			} elsif (m/^\Q^^\E/) {
				s/^\Q^^\E//;
				my ($dt)	= $class->from_sse( $_, $context );
				$args[1]	= $dt->uri_value;
			}
			$lit	=~ s/\\(.)/eval "\"\\$1\""/ge;
			return RDF::Trine::Node::Literal->new( $lit, @args );
		} elsif (my ($id1) = m/^[(]([^)]+)[)]/) {
			s/^[(]([^)]+)[)]\s*//;
			return RDF::Trine::Node::Blank->new( $id1 );
		} elsif (my ($id2) = m/^_:(\S+)/) {
			s/^_:(\S+)\s*//;
			return RDF::Trine::Node::Blank->new( $id2 );
		} elsif (my ($v) = m/^[?](${r_VARNAME})/) {
			s/^[?](${r_VARNAME})\s*//;
			return RDF::Trine::Node::Variable->new( $v );
		} elsif (my ($pn, $ln) = m/^(\S*):(\S*)/o) {
			if ($pn eq '') {
				$pn	= '__DEFAULT__';
			}
			if (my $ns = $context->{namespaces}{ $pn }) {
				s/^(\S+):(\S+)\s*//;
				return RDF::Trine::Node::Resource->new( join('', $ns, $ln) );
			} else {
				throw RDF::Trine::Error -text => "No such namespace '$pn' while parsing SSE QName: >>$_<<";
			}
		} else {
			throw RDF::Trine::Error -text => "Cannot parse SSE node from SSE string: >>$_<<";
		}
	}
}

sub _unicode_escape {
	# based on Unicode::Escape, but without running the string through Encode:: first.
	my $self	= shift;
	my $str		= shift;
	my $us		= Unicode::String->new($str);
	my $rslt	= '';
	while (my $uchar = $us->chop) {
		my $utf8 = $uchar->utf8;
		$rslt = (($utf8 =~ /[\x80-\xff]/) ? '\\u'.uc(unpack('H4', $uchar->utf16be)) : $utf8) . $rslt;
	}
	return $rslt;
}


1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
