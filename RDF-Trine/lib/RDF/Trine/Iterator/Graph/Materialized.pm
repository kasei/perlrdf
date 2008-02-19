# RDF::Trine::Iterator::Graph::Materialized
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Graph::Materialized - Materialized graph class.

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

=over 4

=cut

package RDF::Trine::Iterator::Graph::Materialized;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Scalar::Util qw(reftype);
use base qw(RDF::Trine::Iterator::Graph);

our ($REVISION, $VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$REVISION	= do { my $REV = (qw$Revision: 293 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.000';
}

=item C<< new ( \@results, %args ) >>

Returns a new materialized graph interator. Results must be a reference to an
array containing individual results.

=cut

sub new {
	my $class	= shift;
	my $data	= shift || [];
	if (reftype($data) eq 'CODE') {
		my @data;
		while (my $d = $data->()) {
			push(@data,$d);
		}
		$data	= \@data;
	}
	Carp::confess unless (reftype($data) eq 'ARRAY');
	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args	= @_;
	
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

1;
