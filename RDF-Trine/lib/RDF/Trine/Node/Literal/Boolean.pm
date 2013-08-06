package RDF::Trine::Node::Literal::Boolean;

use utf8;
use Moose::Role;
use RDF::Trine::Error;
use namespace::autoclean;

with qw(
	RDF::Trine::Node::API::Canonicalize
);

sub True {
	shift->new({
		value     => 'true',
		datatype  => q<http://www.w3.org/2001/XMLSchema#boolean>,
	})
}

sub False {
	shift->new({
		value     => 'false',
		datatype  => q<http://www.w3.org/2001/XMLSchema#boolean>,
	})
}

sub _build_is_valid_lexical_form {
	my $self = shift;
	$self->value =~ m{^( true | false | 1 | 0 )$}xi;
}

sub _build_canonical_lexical_form {
	my $self = shift;
	return 'true'  if $self->value =~ m{^( true  | 1 )$}xi;
	return 'false' if $self->value =~ m{^( false | 0 )$}xi;
	throw RDF::Trine::Error -text => "Literal cannot be canonicalized", -object => $self;
}

sub truth
{
	my $self = shift;
	return !!($self->canonical_lexical_form eq 'true');
}

RDF::Trine::Node::Literal::_register_datatype(
	q<http://www.w3.org/2001/XMLSchema#boolean>,
	__PACKAGE__,
);

1;


__END__

=head1 NAME

RDF::Trine::Node::Literal::Boolean - literal subclass for xsd:boolean

=head1 DESCRIPTION

This package should mainly be thought of as for internal use, but does provide
one additional public method, and some extra convenience constructors.

=head2 Constructors

=over

=item C<< True >>

Returns a canonicalized literal C<< "true"^^xsd:boolean >>.

=item C<< False >>

Returns a canonicalized literal C<< "false"^^xsd:boolean >>.

=back

=head2 Methods

=over

=item C<< truth >>

Returns true if the literal is equivalent to C<< "true"^^xsd:boolean >>.

=back
