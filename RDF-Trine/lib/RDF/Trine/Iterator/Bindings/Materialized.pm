# RDF::Trine::Iterator::Bindings::Materialized
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Bindings::Materialized - Materialized bindings class

=head1 VERSION

This document describes RDF::Trine::Iterator::Bindings::Materialized version 1.012

=head1 SYNOPSIS

    use RDF::Trine::Iterator;
    
    my $iterator = RDF::Trine::Iterator::Bindings::Materialized->new( \@data, \@names );
    while (my $row = $iterator->next) {
    	my @vars	= keys %$row;
    	# do something with @vars
    }

    my $iterator = RDF::Trine::Iterator::Bindings->new( \&code, \@names );
    my $miter = $iterator->materialize;
    while (my $row = $miter->next) {
    	my @vars	= keys %$row;
    	# do something with @vars
    }
    $miter->reset; # start the iteration again
    while (my $row = $miter->next) {
        # ...
    }

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Iterator::Bindings> class.

=over 4

=cut

package RDF::Trine::Iterator::Bindings::Materialized;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use base qw(RDF::Trine::Iterator::Bindings);

use Scalar::Util qw(blessed reftype);

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=item C<< new ( \@results, \@names, %args ) >>

Returns a new materialized bindings interator. Results must be a reference to an
array containing individual results.

=cut

sub new {
	my $class	= shift;
	my $data	= shift || [];
	my $names	= shift || [];
	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args	= @_;
	
	if (reftype($data) eq 'CODE') {
		my @rows;
		while (my $row = $data->()) {
			push(@rows, $row);
		}
		$data	= \@rows;
	}
	
	Carp::confess "not an ARRAY: " . Dumper($data) unless (reftype($data) eq 'ARRAY');
	
	my $type	= 'bindings';
	my $index	= 0;
	my $stream	= sub {
		my $data	= $data->[ $index++ ];
		unless (defined($data)) {
			$index	= 0;
		}
		return $data;
	};
	my $self	= $class->SUPER::new( $stream, $names, %args );
	$self->{_data}	= $data;
	$self->{_index}	= \$index;
	
	return $self;
}

=item C<< reset >>

Returns the iterator to its starting position.

=cut

sub reset {
	my $self	= shift;
	${ $self->{_index} }	= 0;
}

=item C<< next >>

Returns the next item in the iterator.

=cut

sub next {
	my $self	= shift;
	my $data	= $self->SUPER::next;
	unless (defined($data)) {
		$self->{_finished}	= 0;
	}
	return $data;
}

=item C<< length >>

Returns the number of elements in the iterator.

=cut

sub length {
	my $self	= shift;
	return scalar(@{ $self->{ _data } });
}

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
