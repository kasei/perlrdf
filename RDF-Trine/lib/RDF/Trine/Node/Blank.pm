package RDF::Trine::Node::Blank;

use utf8;
use Moose;
use MooseX::Aliases;
use namespace::autoclean;

with 'RDF::Trine::Node::API::RDFNode';

alias $_ => 'value' for qw(blank_identifier);

my $COUNTER;
sub BUILDARGS {
	my $class = shift;
	
	if (!@_ or (@_==1 and not defined $_[0])) {
		return +{ value => 'r' . time() . 'r' . $COUNTER++ };
	}

	if (@_==1 and defined $_[0]) {
		return +{ value => $_[0] };
	}

	(@_==1 and ref $_[0] eq 'HASH')
		? $class->SUPER::BUILDARGS(@_)
		: $class->SUPER::BUILDARGS(+{@_})
}

{
	package RDF::Trine::Node::Blank::Exception::InvalidChar;
	use Moose;
	extends 'RDF::Trine::Exception';
	has identifier => (is => 'ro');
}

sub BUILD {
	my $self = shift;
	if ($self->value =~ m/[^A-Za-z0-9]/) {
		RDF::Trine::Node::Blank::Exception::InvalidChar->throw(
			message    => "Only alphanumerics are allowed in N-Triples bnode labels",
			identifier => $self->value,
		);
	}
}

sub type {
	'BLANK'
}

sub as_ntriples {
	sprintf('_:%s', shift->blank_identifier)
}

sub is_blank { 1 }

sub as_string {
	my $self	= shift;
	return	'(' . $self->blank_identifier . ')';
}

__PACKAGE__->meta->make_immutable;
1;

__END__

