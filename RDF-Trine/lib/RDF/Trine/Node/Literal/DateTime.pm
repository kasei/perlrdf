package RDF::Trine::Node::Literal::DateTime;

use utf8;
use Moose;
use namespace::autoclean;

extends 'RDF::Trine::Node::Literal';

with qw(
	RDF::Trine::Node::API::Canonicalize
);

my $regexp = qr/^
	-?
	([1-9]\d{3,}|0\d{3})   # YYYY
	-
	(0[1-9]|1[0-2])        # MM
	-
	(0[1-9]|[12]\d|3[01])  # DD
	T
	(
			([01]\d|2[0-3])     # hh
			:
			([0-5]\d)           # mm
			:
			((?:60|(?:[0-5]\d))(?:\.\d+)?)   # ss
		|
			(24:00:00(?:\.0+)?)
	)
	(Z  |  (\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?  # z
$/xi;

sub _build_is_valid_lexical_form {
	my $self = shift;
	$self->value =~ $regexp;
}

sub _build_canonical_lexical_form {
	shift->value; # XXX - todo!
}

sub does_canonicalization { 0 };

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#dateTime>,
	__PACKAGE__,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

RDF::Trine::Node::Literal::DateTime - literal subclass for xsd:dateTime

=head1 DESCRIPTION

This package should mainly be thought of as for internal use.

