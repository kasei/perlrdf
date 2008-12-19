# RDF::Trine::Promise
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Promise - Promise object

=head1 VERSION

This document describes RDF::Trine::Promise version 0.109.


=head1 SYNOPSIS

    use RDF::Trine::Promise;
    my $promise = RDF::Trine::Promise->new( sub { ... } );
    ...
    my $value = $promise->value;

=head1 METHODS

=over 4

=cut

package RDF::Trine::Promise;

use strict;
use warnings;
no warnings 'redefine';

use JSON;
use Data::Dumper;
use Carp qw(carp);
use Scalar::Util qw(blessed reftype refaddr);

our ($VERSION);
BEGIN {
	$VERSION	= '0.109';
}

=item C<new ( \&closure )>

=cut

sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my $closure		= shift;
	my $self		= bless( [ $closure ], $class );
	return $self;
}

=item C<< value >>

Returns the promised value.

=cut

sub value {
	my $self	= shift;
	if (scalar(@{ $self }) > 1) {
		return $self->[1];
	} else {
		return ($self->[1] = $self->[0]->());
	}
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


