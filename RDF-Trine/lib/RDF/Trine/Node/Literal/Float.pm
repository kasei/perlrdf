package RDF::Trine::Node::Literal::Float;

use utf8;
use Moose;
use namespace::autoclean;

extends 'RDF::Trine::Node::Literal';

with qw(
	RDF::Trine::Node::API::Canonicalize
);

sub _build_is_valid_lexical_form {
	my $self = shift;
	$self->value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/;
}

sub _build_canonical_lexical_form {
	my $self  = shift;
	my $value = $self->value;
	
	if ($value =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/i) {
		no warnings 'uninitialized';
		my $sign  = $1;
		my $inf   = uc $4;
		my $nan   = $5;
		$sign     = '' if $sign eq '+';
		
		return "${sign}$inf" if $inf;
		return 'NaN' if $nan;
		
		$value   = sprintf('%E', $value);
		$value  =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/;
		$sign   = $1;
		$inf    = $4;
		$nan    = $5;
		my $num = $2;
		my $exp = $3;
		$num   =~ s/[.](\d+?)0+/.$1/;
		$exp   =~ tr/e/E/;
		$exp   =~ s/E[+]/E/;
		$exp   =~ s/E(-?)0+([1-9])$/E$1$2/;
		$exp   =~ s/E(-?)0+$/E${1}0/;
		return "${sign}${num}${exp}";
	}
	
	RDF::Trine::Node::Literal::Exception::Canonialization->throw(
		message => "Literal cannot be canonicalized",
		literal => $self,
	);
}

sub numeric_value {
	0 + eval shift->canonical_lexical_form;  # !!!???
}

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#float>,
	__PACKAGE__,
);

# xsd:double appears identical to xsd:float for lexical validation
# and canonicalization purposes. If we need to distinguish later
# then probably just subclass RDF::Trine::Node::Literal::Float, and
# register that instead.
#
RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#double>,
	__PACKAGE__,
);

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

RDF::Trine::Node::Literal::Float - literal subclass for xsd:float and xsd:double

=head1 DESCRIPTION

This package should mainly be thought of as for internal use.

