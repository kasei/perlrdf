package Trine::Literal::Integer;

use utf8;
use Moose;
use namespace::autoclean;

extends 'RDF::Trine::Node::Literal';

with qw(
	RDF::Trine::Node::API::Canonicalize
);

my $regexp = qr{ ^ ([-+])? (\d+) $ }x;

sub _build_is_valid_lexical_form {
	my $self = shift;
	$self->value =~ $regexp;
}

sub _build_canonical_lexical_form {
	my $self = shift;
	if ($self->value =~ $regexp) {
		my $sign = $1 || '';
		my $num  = $2;
		$sign = '' if $sign eq '+';
		$num =~ s/^0+(\d)/$1/;
		return "${sign}${num}";
	}
	RDF::Trine::Node::Literal::Exception::Canonialization->throw(
		message => "Literal cannot be canonicalized",
		literal => $self,
	);
}

sub numeric_value {
	0 + shift->canonical_lexical_form;
}

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#integer>,
	__PACKAGE__,
);

__PACKAGE__->meta->make_immutable;

1;
