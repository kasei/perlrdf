package RDF::Trine::Node::Literal;

use utf8;
use Moose;
use MooseX::Aliases;
use RDF::Trine::Types qw(UriStr);
use MooseX::Types::Moose qw(Str Bool);
use namespace::autoclean;

with 'RDF::Trine::Node::API::RDFNode';

has language => (
	is        => 'ro',
	isa       => Str,
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
			language => $_[2],
			datatype => $_[3],
			_canonicalize_on_construction => $_[4],
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
use constant is_valid_lexical_form => '0E0';  # 0 but true
sub canonical_lexical_form { shift->value };
use constant is_canonical_lexical_form => 1;
sub canonicalize { shift };
use constant numeric_value => undef;
use constant does_canonicalization => 0;
use constant does_lexical_validation => 0;

1;

__END__
