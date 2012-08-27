package RDF::Trine::Node::API::RDFNode;

use utf8;
use Moose::Role;
use MooseX::Types::Moose qw(Str);

with qw(
	RDF::Trine::Node::API::BaseNode
);

requires qw(
	as_ntriples
);

has value => (
	is   => 'ro',
	isa  => Str,
);

has _escaped_value => (
	is       => 'ro',
	isa      => Str,
	lazy     => 1,
	builder  => '_build_escaped_value',
	init_arg => undef,
);

sub _build_escaped_value {
	my $self = shift;
	my $str  = $self->value;
	
	if ($str =~ /\A[^\\\n\t\r"\x{10000}-\x{10ffff}\x{7f}-\x{ffff}\x{00}-\x{08}\x{0b}-\x{0c}\x{0e}-\x{1f}]*\z/sm) {
		# hot path - no special characters to escape, just printable ascii
		return $str;
	}
	
	# slow path - escape all the special characters
	my $rslt = '';
	while (length $str) {
		if (my ($ascii) = $str =~ /^([A-Za-z0-9 \t]+)/) {
			$rslt .= $ascii;
			substr($str, 0, length $ascii) = '';
		}
		else {
			my $utf8 = substr($str,0,1,'');
			if ($utf8 eq '\\') {
				$rslt .= '\\\\';
			}
			elsif ($utf8 =~ /^[\x{10000}-\x{10ffff}]$/) {
				$rslt .= sprintf('\\U%08X', ord($utf8));
			}
			elsif ($utf8 =~ /^[\x7f-\x{ffff}]$/) {
				$rslt .= sprintf('\\u%04X', ord($utf8));
			}
			elsif ($utf8 =~ /^[\x00-\x08\x0b-\x0c\x0e-\x1f]$/) {
				$rslt .= sprintf('\\u%04X', ord($utf8));
			}
			else {
				$rslt .= $utf8;
			}
		}
	}
	$rslt =~ s/\n/\\n/g;
	$rslt =~ s/\t/\\t/g;
	$rslt =~ s/\r/\\r/g;
	$rslt =~ s/"/\\"/g;
	return $rslt;
}

sub BUILDARGS {
	if (@_ == 2 and not ref $_[1]) {
		return +{ value => $_[1] };
	}
	my $class = shift;
	(@_==1 and ref $_[0] eq 'HASH')
		? $class->Moose::Object::BUILDARGS(@_)
		: $class->Moose::Object::BUILDARGS(+{@_})
}

sub sse {
	shift->as_ntriples # not strictly correct
}

1;

__END__

=head1 NAME

RDF::Trine::Node::API::RDFNode - role for RDF-specific role functionality

=head1 DESCRIPTION

This role extends RDF::Trine::Node::API::BaseNode for nodes that occur
in RDF - i.e. literals, URIs and blank nodes.

=head2 Requires

This role requires consuming classes to implement the following methods:

=over

=item C<< as_ntriples >>

=back

=head2 Constructor

While this role cannot be instantiated directly, any classes that consume
it will have their constructors modified to accept

  $class->new($value)

as an alternative to the standard Moose-style hash constructor.

=head2 Attributes

=over

=item C<< value >>

The primary string value of the node. In the case of a resource, this is its
absolute IRI; in the case of a literal, it's the literal value (minus any
datatype or language tag).

=back

=head2 Methods

This role provides the following methods:

=over

=item C<< sse >>

Returns an SSE-inspired string representation of the node.

=back




