# RDF::Trine::Node
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node - Base class for RDF Nodes

=head1 VERSION

This document describes RDF::Trine::Node version 1.012

=cut

package RDF::Trine::Node;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION, @ISA, @EXPORT_OK);
BEGIN {
	$VERSION	= '1.012';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(ntriples_escape);
}

use Scalar::Util qw(blessed refaddr);

use RDF::Trine::Node::Nil;
use RDF::Trine::Node::Blank;
use RDF::Trine::Node::Literal;
use RDF::Trine::Node::Resource;
use RDF::Trine::Node::Variable;


=head1 FUNCTIONS

=over 4

=item C<< ntriples_escape ( $value ) >>

Returns the passed string value with special characters (control characters,
Unicode, etc.) escaped, suitable for printing inside an N-Triples or Turtle
encoded literal.

=cut

sub ntriples_escape {
	my $class	= __PACKAGE__;
	return $class->_unicode_escape( @_ );
}

=back

=head1 METHODS

=over 4

=item C<< is_node >>

Returns true if this object is a RDF node, false otherwise.

=cut

sub is_node {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node'));
}

=item C<< is_nil >>

Returns true if this object is the nil-valued node.

=cut

sub is_nil {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Trine::Node::Nil'));
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
	Carp::confess unless ($self->can('sse'));
	return $self->sse;
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	return $_[0]->sse;
}

=item C<< sse >>

Returns the SSE serialization of the node.

=cut

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node));
	return (refaddr($self) == refaddr($node));
}

=item C<< compare ( $node_a, $node_b ) >>

Returns -1, 0, or 1 if $node_a sorts less than, equal to, or greater than
$node_b in the defined SPARQL ordering, respectively. This function may be
used as the function argument to C<<sort>>.

=cut

my %order	= (
	NIL		=> 0,
	BLANK	=> 1,
	URI		=> 2,
	LITERAL	=> 3,
);
sub compare {
	my $a	= shift;
	my $b	= shift;
	return -1 unless blessed($a);
	return 1 unless blessed($b);
	
	# (Lowest) no value assigned to the variable or expression in this solution.
	# Blank nodes
	# IRIs
	# RDF literals (plain < xsd:string)
	my $at	= $a->type;
	my $bt	= $b->type;
	if ($a->type ne $b->type) {
		my $an	= $order{ $at };
		my $bn	= $order{ $bt };
		return ($an <=> $bn);
	} else {
		return $a->_compare( $b );
	}
}

=item C<< as_hashref >>

Returns a hashref representing the node in an RDF/JSON-like manner.

See C<< as_hashref >> at L<RDF::Trine::Model> for full documentation of the
hashref format.

=cut

sub as_hashref {
	my $self	= shift;
	my $o = {};
	if ($self->isa('RDF::Trine::Node::Literal')) {
		$o->{'type'}		= 'literal';
		$o->{'value'}		= $self->literal_value;
		$o->{'lang'}		= $self->literal_value_language
			if $self->has_language;
		$o->{'datatype'}	= $self->literal_datatype
			if $self->has_datatype;
	} else {
		$o->{'type'}		= $self->isa('RDF::Trine::Node::Blank') ? 'bnode' : 'uri';
		$o->{'value'}		= $self->isa('RDF::Trine::Node::Blank') ? 
			('_:'.$self->blank_identifier) :
			$self->uri ;
	}
	return $o;
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
	$_			= $_[0];
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

sub _unicode_escape {
	my $self	= shift;
	my $str		= shift;
	
	if ($str =~ /\A[^\\\n\t\r"\x{10000}-\x{10ffff}\x{7f}-\x{ffff}\x{00}-\x{08}\x{0b}-\x{0c}\x{0e}-\x{1f}]*\z/sm) {
		# hot path - no special characters to escape, just printable ascii
		return $str;
	} else {
		# slow path - escape all the special characters
		my $rslt	= '';
		while (length($str)) {
			if (my ($ascii) = $str =~ /^([A-Za-z0-9 \t]+)/) {
				$rslt	.= $ascii;
				substr($str, 0, length($ascii))	= '';
			} else {
				my $utf8	= substr($str,0,1,'');
				if ($utf8 eq '\\') {
					$rslt	.= '\\\\';
				} elsif ($utf8 =~ /^[\x{10000}-\x{10ffff}]$/) {
					$rslt	.= sprintf('\\U%08X', ord($utf8));
				} elsif ($utf8 =~ /^[\x7f-\x{ffff}]$/) {
		#			$rslt	= '\\u'.uc(unpack('H4', $uchar->utf16be)) . $rslt;
					$rslt	.= sprintf('\\u%04X', ord($utf8));
				} elsif ($utf8 =~ /^[\x00-\x08\x0b-\x0c\x0e-\x1f]$/) {
					$rslt	.= sprintf('\\u%04X', ord($utf8));
				} else {
					$rslt	.= $utf8;
				}
			}
		}
#	 	$rslt		=~ s/\\/\\\\/g;
		$rslt		=~ s/\n/\\n/g;
		$rslt		=~ s/\t/\\t/g;
		$rslt		=~ s/\r/\\r/g;
		$rslt		=~ s/"/\\"/g;
		return $rslt;
	}
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
