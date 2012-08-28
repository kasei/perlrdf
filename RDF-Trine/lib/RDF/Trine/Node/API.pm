package RDF::Trine::Node::API;

use utf8;
use Moose::Role;

requires qw(
	sse
	type
	_compare
);

sub is_node     { 1 } 
sub is_blank    { 0 } 
sub is_resource { 0 } 
sub is_literal  { 0 } 
sub is_nil      { 0 } 
sub is_variable { 0 } 

sub as_string { shift->sse }

sub equal {
	my ($x, $y) = @_;
	return unless blessed($y) && $y->can('type') && $x->type eq $y->type;
	$x->sse eq $y->sse;
}

my %order = (
	NIL      => 0,
	VAR      => 1,
	BLANK    => 2,
	URI      => 3,
	LITERAL  => 4,
);

sub compare {
	my $A  = shift;
	my $B  = shift;
	return -1 unless blessed($A);
	return  1 unless blessed($B);
	
	my $at = $A->type;
	my $bt = $B->type;
	if ($at ne $bt) {
		return ($order{ $at } <=> $order{ $bt });
	}
	
	return $A->_compare($B);
}

{
	package RDF::Trine::Node::API::Exception::FromSSE;
	use Moose;
	extends 'RDF::Trine::Exception';
}

my $r_PN_CHARS_BASE  = qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
my $r_PN_CHARS_U     = qr/(_|${r_PN_CHARS_BASE})/;
my $r_VARNAME        = qr/((${r_PN_CHARS_U}|[0-9])(${r_PN_CHARS_U}|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}])*)/;
sub from_sse {
	my $class   = shift;
	my $context = $_[1];
	$_          = $_[0];
	if (my ($iri) = m/^<([^>]+)>/o) {
		s/^<([^>]+)>\s*//;
		return RDF::Trine::Node::Resource->new( $iri );
	}
	
	elsif (my ($lit) = m/^"(([^"\\]+|\\([\\"nt]))+)"/o) {
		my @args;
		s/^"(([^"\\]+|\\([\\"nt]))+)"//;
		if (my ($lang) = m/[@](\S+)/) {
			s/[@](\S+)\s*//;
			$args[0] = $lang;
		}
		elsif (m/^\Q^^\E/) {
			s/^\Q^^\E//;
			my ($dt) = $class->from_sse( $_, $context );
			$args[1] = $dt->uri_value;
		}
		$lit =~ s/\\(.)/eval "\"\\$1\""/ge;
		return RDF::Trine::Node::Literal->new( $lit, @args );
	}
	
	elsif (my ($id1) = m/^[(]([^)]+)[)]/) {
		s/^[(]([^)]+)[)]\s*//;
		return RDF::Trine::Node::Blank->new( $id1 );
	}
	
	elsif (my ($id2) = m/^_:(\S+)/) {
		s/^_:(\S+)\s*//;
		return RDF::Trine::Node::Blank->new( $id2 );
	}
	
	elsif (my ($v) = m/^[?](${r_VARNAME})/) {
		s/^[?](${r_VARNAME})\s*//;
		return RDF::Trine::Node::Variable->new( $v );
	}
	
	elsif (my ($pn, $ln) = m/^(\S*):(\S*)/o) {
		if ($pn eq '') {
			$pn = '__DEFAULT__';
		}
		if (my $ns = $context->{namespaces}{ $pn }) {
			s/^(\S+):(\S+)\s*//;
			return RDF::Trine::Node::Resource->new( join('', $ns, $ln) );
		}
		
		else {
			RDF::Trine::Node::API::Exception::FromSSE->throw(
				message => "No such namespace '$pn' while parsing SSE QName: >>$_<<",
			);
		}
	}
	
	else {
		RDF::Trine::Node::API::Exception::FromSSE->throw(
			message => "Cannot parse SSE node from SSE string: >>$_<<",
		);
	}
}

for my $sub (qw(compare from_sse))
{
	no strict 'refs';
	*{"RDF::Trine::Node::$sub"} = sub
	{
		Carp::carp("RDF::Trine::Node::$sub is deprecated; use RDF::Trine::Node::API::$sub instead");
		goto \&{$sub};
	}
}

1;

__END__

=head1 NAME

RDF::Trine::Node::API - role for basic node functionality

=head1 DESCRIPTION

This role provides the basic functionality that all RDF::Trine::Node-type
objects are expected to have. Classes consuming this role may potentially
be used within statements, patterns and so on.

=head2 Requires

This role requires consuming classes to implement the following methods:

=over

=item C<< sse >>

=item C<< type >>

=item C<< _compare >>

=back

=head2 Constructor

=over

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Methods

This role provides the following methods:

=over

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns true if the node is a blank node.

=item C<< is_resource >>

Returns true if the node is a resource (URI/IRI).

=item C<< is_literal >>

Returns true if the node is a literal.

=item C<< is_nil >>

Returns true if the node is the magical nil node.

=item C<< is_variable >>

Returns true if the node is a variable.

=item C<< as_string >>

Returns a string representation of the node (currently identical to the SSE).

=item C<< equal($other) >>

Returns true if this node and is the same node as the other node.

=item C<< compare($other) >>

Like the C<< <=> >> operator, but sorts according to SPARQL ordering.

=back


