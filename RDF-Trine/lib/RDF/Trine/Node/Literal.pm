package RDF::Trine::Node::Literal;

use utf8;
use Moose;
use MooseX::Aliases;
use RDF::Trine::Types qw(UriStr LanguageTag);
use MooseX::Types::Moose qw(Str Bool);
use namespace::autoclean;

with 'RDF::Trine::Node::API::RDFNode';

has language => (
	is        => 'ro',
	isa       => LanguageTag,
	predicate => "has_language",
	traits    => [qw( MooseX::UndefTolerant::Attribute )],
);

has datatype => (
	is        => 'ro',
	isa       => UriStr,
	predicate => "has_datatype",
	traits    => [qw( MooseX::UndefTolerant::Attribute )],
	coerce    => 1,
);

has '+value' => (writer => '_set_value');
has '_canonicalize_on_construction' => (
	is        => 'ro',
	isa       => Bool,
	default   => 0,
);

alias $_ => 'value' for qw(literal_value);
alias literal_value_language => 'language';
alias literal_datatype => 'datatype';

sub BUILDARGS {
	if (@_ >= 2 and @_ <= 5 and not ref $_[1]) {
		return +{
			value    => $_[1],
			language => (length $_[2] ? $_[2] : undef),
			datatype => (length $_[3] ? $_[3] : undef),
			_canonicalize_on_construction => $_[4] || 0,
		}
	}
	my $class = shift;
	(@_==1 and ref $_[0] eq 'HASH')
		? $class->SUPER::BUILDARGS(@_)
		: $class->SUPER::BUILDARGS(+{@_})
}

my %SUBCLASS;

# This is not really intended as a third-party extensibility point.
# It's really for Trine-internal use.
sub _register_datatype {
	my ($datatype, $sc) = @_;
	$datatype = $datatype->value if blessed $datatype;
	$SUBCLASS{ $datatype } ||= $sc;
}
sub _registered_datatypes {
	%SUBCLASS;
}

require RDF::Trine::Node::Literal::Boolean;
require RDF::Trine::Node::Literal::Integer;
require RDF::Trine::Node::Literal::Decimal;
require RDF::Trine::Node::Literal::Float;
require RDF::Trine::Node::Literal::DateTime;

{
	package RDF::Trine::Node::Literal::Exception::NotPossible;
	use Moose;
	extends 'RDF::Trine::Exception';
	has literal => (is => 'ro');
}

sub BUILD {
	my $self = shift;
	
	RDF::Trine::Node::Literal::Exception::NotPossible->throw(
		message => "cannot have both a language and datatype",
		literal => $self,
	) if $self->has_datatype && $self->has_language;
	
	if ($self->has_datatype and my $r = $SUBCLASS{ $self->datatype }) {
		$r->meta->rebless_instance($self);
	}
	
	if ($self->_canonicalize_on_construction and $self->does('RDF::Trine::Node::API::Canonicalize')) {
		$self->_set_value( $self->canonical_lexical_form );
	}
}

sub new_canonical {
	my $class = shift;
	my $self  = $class->new(@_);
	if ($self->does('RDF::Trine::Node::API::Canonicalize')) {
		return $self->canonicalize;
	}
	return $self;
}

sub type {
	'LITERAL'
}

sub as_ntriples {
	my $self = shift;
	return sprintf("\"%s\"^^<%s>", $self->_escaped_value, $self->datatype)
		if $self->has_datatype;
	return sprintf("\"%s\"\@%s", $self->_escaped_value, $self->language)
		if $self->has_language;
	return sprintf("\"%s\"", $self->_escaped_value);
}

sub sse {
	my $self = shift;
	return sprintf("\"%s\"^^<%s>", $self->value, $self->datatype)
		if $self->has_datatype;
	return sprintf("\"%s\"\@%s", $self->value, $self->language)
		if $self->has_language;
	return sprintf("\"%s\"", $self->value);
}

sub is_literal { 1 }

my $numeric_datatypes = qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>;
sub is_numeric_type {
	my $self = shift;
	$self->has_datatype and $self->literal_datatype =~ $numeric_datatypes;
}

sub _compare {
	my ($A, $B) = @_;
	
	return $A->value cmp $B->value
		unless $A->value eq $B->value;
	
	return $A->language cmp $B->language
		if $A->has_language && $B->has_language;
	
	return $A->datatype cmp $B->datatype
		if $A->has_datatype && $B->has_datatype;
	
	return  1 if $A->has_datatype;
	return -1 if $B->has_datatype;
	return  0;
}

# stub stuff for subclasses
sub is_valid_lexical_form     { '0E0' }  # 0 but true
sub canonical_lexical_form    { shift->value }
sub is_canonical_lexical_form { '0E0' }
sub canonicalize              { +shift }
sub numeric_value             { +undef }
sub does_canonicalization     { 0 }
sub does_lexical_validation   { 0 }

1;

__END__

=head1 NAME

RDF::Trine::Node::Literal - an RDF literal

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new($value) >>

=item C<< new($value, $language) >>

=item C<< new($value, undef, $datatype) >>

=item C<< new({ value => $value, %attrs }) >>

Constructs a literal with an optional language code or datatype URI (but not both).

=item C<< new_canonical >>

The same as C<new> but canonicalizes the literal's lexical form if possible.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Attributes

=over

=item C<< value >>

The literal value.

=item C<< language >>

The literal language, if any. An additional method C<< has_language >> is also
provided.

=item C<< datatype >>

The literal datatype URI, if any. An additional method C<< has_datatype >> is
also provided.

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< sse >>

Returns the node in SSE syntax.

=item C<< type >>

Returns the string 'VAR'.

=item C<< is_node >>

Returns true.

=item C<< is_blank >>

Returns false.

=item C<< is_resource >>

Returns false.

=item C<< is_literal >>

Returns true.

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

=item C<< is_valid_lexical_form >>

Returns true if the literal value is lexically valid according to its datatype.
For example, "1" is a lexically valid xsd:integer, but "one" is not.

If the validity cannot be determined (e.g. unknown datatype) then returns
the string "0E0" which evaluates to true in a boolean context, but 0 in a
numeric context.

=item C<< is_canonical_lexical_form >>

Returns true if the literal value is canonical according to its datatype.
For example, "1" is a canonical xsd:integer; "0001" is a lexically valid, but
non-canonical representation of the same number.

If the canonicity cannot be determined (e.g. unknown datatype) then returns
the string "0E0" which evaluates to true in a boolean context, but 0 in a
numeric context.

sub numeric_value {
	my $self	= shift;
	if ($self->is_numeric_type) {
		my $value	= $self->literal_value;
		if (looks_like_number($value)) {
			my $v	= 0 + eval "$value";	## no critic (ProhibitStringyEval)
			return $v;
		} else {
			throw RDF::Query::Error::TypeError -text => "Literal with numeric type does not appear to have numeric value.";
		}
	} elsif (not $self->has_datatype) {
		if (looks_like_number($self->literal_value)) {
			return 0+$self->literal_value;
		} else {
			return;
		}
	} elsif ($self->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		return ($self->literal_value eq 'true') ? 1 : 0;
	} else {
		return;
	}
}

Returns true if the datatype URI is one of the recognised numeric datatypes
from XML Schema.

=item C<< canonical_lexical_form >>

Returns the canonical lexical form of the literal, as a string. If it cannot
be canonicalized, returns the current value as-is.

=item C<< canonicalize >>

As per C<< canonical_lexical_form >> but returns another
L<RDF::Trine::Node::Literal> object.

=item C<< numeric_value >>

Returns the numeric value of the literal, if the literal has a numeric
datatype. Returns undef otherwise.

=item C<< does_canonicalization >>

Returns true if canonicalization is supported for this datatype.

=item C<< does_lexical_validation >>

Returns true if lexical validation is supported for this datatype.

=back

