package RDF::Trine::Node::Variable;

=head1 NAME

RDF::Trine::Node::Variable - RDF Node class for variables

=head1 VERSION

This document describes RDF::Trine::Node::Variable version 1.007

=cut

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

use Moose;
use MooseX::Types::Moose qw(Str);
use MooseX::Aliases;
use namespace::autoclean;
use base qw(RDF::Trine::Node);

with 'RDF::Trine::Node::API';

has 'value' => (
	is   		=> 'ro',
	isa  		=> 'Str',
	required	=> 1,
	alias		=> 'name',
);

sub BUILDARGS {
	if (@_ == 2 and not ref $_[1]) {
		return +{ value => $_[1] };
	} elsif (@_ == 3 and $_[1] eq 'name') {
		$_[1]	= 'value';
	}
	return shift->SUPER::BUILDARGS(@_);
}

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.007';
}

######################################################################

use overload	'""'	=> sub { $_[0]->sse },
			;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Node> class.

=over 4

=cut

=item C<new ( $name )>

Returns a new Variable structure.

=cut

=item C<< name >>

Returns the name of the variable.

=cut

=item C<< sse >>

Returns the SSE string for this variable.

=cut

sub sse {
	my $self	= shift;
	my $name	= $self->name;
	return qq(?${name});
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return '?' . $self->name;
}

=item C<< value >>

Returns the variable name.

=cut

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	my $self	= shift;
	throw RDF::Trine::Error::UnimplementedError -text => "Variable nodes aren't allowed in NTriples";
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'VAR';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node'));
	return 0 unless ($self->type eq $node->type);
	return ($self->name eq $node->name);
}

# called to compare two nodes of the same type
sub _compare {
	my $a	= shift;
	my $b	= shift;
	return ($a->name cmp $b->name);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
