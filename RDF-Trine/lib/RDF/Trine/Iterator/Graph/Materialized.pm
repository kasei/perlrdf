# RDF::Trine::Iterator::Graph::Materialized
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Graph::Materialized - Materialized graph class

=head1 VERSION

This document describes RDF::Trine::Iterator::Graph::Materialized version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Iterator;
 
 my $iterator = RDF::Trine::Iterator::Graph::Materialized->new( \@data );
 while (my $statement = $iterator->next) {
 	# do something with $statement
 }

 my $iterator = RDF::Trine::Iterator::Graph->new( \&code );
 my $miter = $iterator->materialize;
 while (my $statement = $miter->next) {
 	# do something with $statement
 }
 $miter->reset; # start the iteration again
 while (my $statement = $miter->next) {
     # ...
 }

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Iterator::Graph> class.

=over 4

=cut

package RDF::Trine::Iterator::Graph::Materialized;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(reftype);
use base qw(RDF::Trine::Iterator::Graph);

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=item C<< new ( \@results, %args ) >>

Returns a new materialized graph interator. Results must be a reference to an
array containing individual results.

=cut

sub new {
	my $class	= shift;
	my $data	= shift || [];
	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args	= @_;
	
	if (reftype($data) eq 'CODE') {
		my @data;
		while (my $d = $data->()) {
			push(@data,$d);
		}
		$data	= \@data;
	}
	
	Carp::confess unless (reftype($data) eq 'ARRAY');
	
	my $type	= 'graph';
	my $index	= 0;
	my $stream	= sub {
		my $data	= $data->[ $index++ ];
		unless (defined($data)) {
			$index	= 0;
		}
		return $data;
	};
	my $self	= $class->SUPER::new( $stream, %args );
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
