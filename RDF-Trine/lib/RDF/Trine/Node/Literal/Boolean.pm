package Trine::Literal::Boolean;

use utf8;
use Moose;
use namespace::autoclean;

extends 'RDF::Trine::Node::Literal';

with qw(
	RDF::Trine::Node::API::Canonicalize
);

sub _build_is_valid_lexical_form {
	my $self = shift;
	$self->value =~ m{^( true | false | 1 | 0 )$}xi;
}

sub _build_canonical_lexical_form {
	my $self = shift;
	return 'true'  if $self->value =~ m{^( true  | 1 )$}xi;
	return 'false' if $self->value =~ m{^( false | 0 )$}xi;
	RDF::Trine::Node::Literal::Exception::Canonialization->throw(
		message => "Literal cannot be canonicalized",
		literal => $self,
	);
}

sub truth
{
	my $self = shift;
	return ($self->canonical_lexical_form eq 'true');
}

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#boolean>,
	__PACKAGE__,
);

__PACKAGE__->meta->make_immutable;

1;
