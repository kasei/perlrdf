package RDF::Trine::Node::Variable;

use utf8;
use Moose;
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

with 'RDF::Trine::Node::API::BaseNode';

has name => (
	is   => 'ro',
	isa  => Str,
);

sub BUILDARGS {
	if (@_ == 2 and not ref $_[1]) {
		return +{ name => $_[1] };
	}
	return shift->SUPER::BUILDARGS(@_);
}

sub type {
	'VAR'
}

sub sse {
	sprintf '?%s', shift->name;
}

sub from_sse {
	...;
}

{
	package RDF::Trine::Node::Variable::Exception::NTriples;
	use Moose;
	extends 'RDF::Trine::Exception';
	has variable => (is => 'ro');
}

sub as_ntriples {
	RDF::Trine::Node::Variable::Exception::NTriples->throw(
		message  => "Variable nodes aren't allowed in NTriples",
		variable => $_[0],
	);
}

sub is_variable { 1 }

__PACKAGE__->meta->make_immutable;
1;

