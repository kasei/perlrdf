package RDF::Trine::Node::Literal::Decimal;

use utf8;
use Moose::Role;
use RDF::Trine::Error;
use namespace::autoclean;

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
	warn "-> no\n";
	return 0;
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
	
	throw RDF::Trine::Error -text => "Literal cannot be canonicalized", -object => $self;
}

sub numeric_value {
	my $self	= shift;
	my $v		= $self->canonical_lexical_form;
	warn "canonical value: $v";
	return 0 + $v
}

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#decimal>,
	__PACKAGE__,
);

1;

__END__

=head1 NAME

RDF::Trine::Node::Literal::Decimal - literal subclass for xsd:decimal

=head1 DESCRIPTION

This package should mainly be thought of as for internal use.

