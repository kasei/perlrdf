package RDF::Trine::Node::Resource;

use utf8;

### TODO
### - return RDF::Trine::Node::Nil if appropriate!

use URI 1.52;
use Encode;

use Moose;
use MooseX::Aliases;
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

has as_ntriples => (
	is        => 'ro',
	isa       => Str,
	lazy      => 1,
	builder   => '_build_as_ntriples',
	init_arg  => undef,
);

has _uriobj => (
	is        => 'ro',
	isa       => 'URI',
	lazy      => 1,
	default   => sub { URI->new( encode_utf8(shift->uri_value) ) },
	init_arg  => undef,
	handles   => [qw[ scheme opaque path fragment authority host port ]],
);

with 'RDF::Trine::Node::API::RDFNode';

alias $_ => 'value' for qw(uri uri_value);

around BUILDARGS => sub {
	my $orig = shift;
	my $self = shift;
	if (@_==2 and not ref $_[0] eq 'HASH') {
		my $tmp = $self->new_with_base(@_);
		return +{ %$tmp }; # !!!
	}
	if (@_==1 and not ref $_[0] eq 'HASH') {
		return +{ value => $_[0] }
	}
	if (@_==1 and ref $_[0] eq 'HASH') {
		return $_[0];
	}
	my %hash = @_;
	return \%hash;
};

sub new_with_base {
	my ($class, $uri, $base) = @_;
	$base = $base->uri if blessed $base && $base->can('uri'); # :-(
	$base = "" unless defined $base;
	$class->new( URI->new_abs($uri, "$base")->as_iri );
}

sub type {
	'URI'
}

sub _build_as_ntriples {
	my $self   = shift;
	my $string = $self->_uriobj->canonical;
	return '<'.$string.'>';
}

sub as_string {
	my $self   = shift;
	return '<'.$self->value.'>';
}

{
	package RDF::Trine::Node::Resource::Exception::QName;
	use Moose;
	extends 'RDF::Trine::Exception';
	has resource => (is => 'ro');
}

sub qname {
	my $self = shift;
	my $uri  = $self->uri_value;

	our $r_PN_CHARS_BASE  ||= qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
	our $r_PN_CHARS_U     ||= qr/(_|${r_PN_CHARS_BASE})/;
	our $r_PN_CHARS       ||= qr/${r_PN_CHARS_U}|-|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]/;
	our $r_PN_LOCAL       ||= qr/((${r_PN_CHARS_U})((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
	
	if ($uri =~ m/${r_PN_LOCAL}$/) {
		my $ln	= $1;
		my $ns	= substr($uri, 0, length($uri)-length($ln));
		return ($ns, $ln);
	}
	else {
		RDF::Trine::Node::Resource::Exception::QName->throw(
			message  => "Can't turn IRI $uri into a QName.",
			resource => $self,
		);
	}
}

sub is_resource { 1 }

around sse => sub
{
	my $orig = shift;
	my $self = shift;
	my ($context) = @_;
	
	if ($context) {
		my $uri  = $self->uri_value;
		my $ns   = $context->{namespaces} || {};
		my %ns   = %$ns;
		foreach my $k (keys %ns) {
			my $v = $ns{ $k };
			if (index($uri, $v) == 0) {
				my $qname = join ':' => ($k, substr($uri, length $v));
				return $qname;
			}
		}
	}
	
	return $self->$orig(@_);
};

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

RDF::Trine::Node::Resource - an IRI node

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new($iri) >>

=item C<< new({ value => $iri, %attrs }) >>

Constructs a resource node.

=item C<< new_with_base($iri, $base) >>

Constructs a resource node from a possibly relative IRI.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Attributes

=over

=item C<< value >>

The URI.

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< sse >>

Returns the node in SSE syntax.

=item C<< type >>

Returns the string 'URI'.

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns false.

=item C<< is_resource >>

Returns true.

=item C<< is_literal >>

Returns false.

=item C<< is_nil >>

Returns false.

=item C<< is_variable >>

Returns false.

=item C<< as_string >>

Returns a string representation of the node (currently identical to the SSE).

=item C<< equal($other) >>

Returns true if this node and is the same node as the other node.

=item C<< compare($other) >>

Like the C<< <=> >> operator, but sorts according to SPARQL ordering.

=item C<< as_ntriples >>

Returns an N-Triples representation of the node.

=item C<< qname >>

Splits the IRI into a prefix, suffix pair, in preparation for making a QName.

=item C<< scheme >>, C<< opaque >>, C<< path >>, C<< fragment >>, C<< authority >>, C<< host >>, C<< port >>

Returns components of the URI. (See L<URI>.)

=back


