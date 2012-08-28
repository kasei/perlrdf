package RDF::Trine::Node::Literal::Decimal;

use utf8;
use Moose;
use namespace::autoclean;

extends 'RDF::Trine::Node::Literal';

with qw(
	RDF::Trine::Node::API::Canonicalize
);

my $regexp = qr{ ^ ([-+])? (\d+) $ }x;

sub _build_is_valid_lexical_form {
	my $value = shift->value;
	if ($value =~ m/^([-+])?((\d+)[.]\d+)$/) {
		return 1;
	}
	elsif ($value =~ m/^([-+])?([.]\d+)$/) {
		return 1;
	}
	return;
}

sub _build_canonical_lexical_form {
	my $self  = shift;
	my $value = $self->value;
	
	if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
		my $sign  = $1 || '';
		my $num   = $2;
		my $int   = $3;
		my $frac  = $4;
		$sign     = '' if $sign eq '+';
		$num     =~ s/^0+(.)/$1/;
		$num     =~ s/[.](\d)0+$/.$1/;
		if ($num =~ /^[.]/) {
			$num = "0$num";
		}
		if ($num !~ /[.]/) {
			$num = "${num}.0";
		}
		return "${sign}${num}";
	}
	
	if ($value =~ m/^([-+])?([.]\d+)$/) {
		my $sign  = $1 || '';
		my $num   = $2;
		$sign     = '' if $sign eq '+';
		$num     =~ s/^0+(.)/$1/;
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
	q<http://www.w3.org/2001/XMLSchema#decimal>,
	__PACKAGE__,
);

__PACKAGE__->meta->make_immutable;

1;
