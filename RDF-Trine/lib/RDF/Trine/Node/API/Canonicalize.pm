package RDF::Trine::Node::API::Canonicalize;

use utf8;
use Moose::Role;
use MooseX::Types::Moose qw(Str);

requires qw(
	value
	datatype
	_build_is_valid_lexical_form
	_build_canonical_lexical_form
);

sub does_canonicalization   { 1 }
sub does_lexical_validation { 1 }

has is_valid_lexical_form => (
	is        => 'ro',
	isa       => Str,
	lazy      => 1,
	builder   => '_build_is_valid_lexical_form',
	init_arg  => undef,
);
	
has canonical_lexical_form => (
	is        => 'ro',
	isa       => Str,
	lazy      => 1,
	builder   => '_build_canonical_lexical_form',
	init_arg  => undef,
);

sub is_canonical_lexical_form
{
	my $self = shift;
	$self->value eq $self->canonical_lexical_form
}

sub canonicalize
{
	my $self = shift;
	RDF::Trine::Node::Literal->new({
		value    => $self->canonical_lexical_form,
		datatype => $self->datatype,
	});
}	

{
	package RDF::Trine::Node::Literal::Exception::Canonialization;
	use Moose;
	extends 'RDF::Trine::Exception';
	has literal => (is => 'ro');
}

1;

__END__

