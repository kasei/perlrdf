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

sub new_with_base {
	my ($class, $uri, $base) = @_;
	$base = $base->uri if blessed $base && $base->can('uri'); # :-(
	$class->new( URI->new_abs($uri, "$base")->as_iri );
}

sub type {
	'URI'
}

sub _build_as_ntriples {
	my $self   = shift;
	my $string = URI->new( encode_utf8($self->uri_value) )->canonical;
	return '<'.$string.'>';
}

sub as_string {
	my $self   = shift;
	return '<'.$self->uri_value.'>';
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
