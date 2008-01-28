# RDF::Trine::Iterator::Bindings::Materialized
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Bindings::Materialized - Materialized bindings class.

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

=over 4

=cut

package RDF::Trine::Iterator::Bindings::Materialized;

use strict;
use warnings;
use Data::Dumper;
use base qw(RDF::Trine::Iterator::Bindings);

our ($REVISION, $VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$REVISION	= do { my $REV = (qw$Revision: 293 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.000';
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

1;
