# RDF::Query::Logger
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Logger - Base class for logging objects

=head1 METHODS

=over 4

=cut

package RDF::Query::Logger;

our ($VERSION);
BEGIN {
	$VERSION	= '2.100';
}

use strict;
use warnings;
no warnings 'redefine';

use Set::Scalar;
use Data::Dumper;
use Scalar::Util qw(blessed);


=item C<< new >>

Return a new logger object.

=cut

sub new {
	my $class	= shift;
	my $self	= bless( {}, $class );
	return $self;
}


=item C<< log ( $key [, $value ] ) >>

If no logger object is associated with this query object, does nothing.
Otherwise, return or set the corresponding value depending on whether a
C<< $value >> is specified.

=cut

sub log {
	my $self	= shift;
	my $key		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.logger");
	if (@_) {
		my $value	= shift;
		local($Data::Dumper::Indent)	= 0;
		$l->trace("setting " . Data::Dumper->Dump([$value], [$key]));
		$self->{ $key }	= $value;
	}
	return $self->{ $key };
}

=item C<< push_value ( $key, @values ) >>

=cut

sub push_value {
	my $self	= shift;
	my $key		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.logger");
	my $array	= $self->{ $key } ||= [];
	my @values	= @_;
	$l->trace("adding values " . Data::Dumper->Dump([\@values], [$key]));
	push( @$array, @values );
}

=item C<< add_key_value ( $key, $k => $v ) >>

=cut

sub add_key_value {
	my $self	= shift;
	my $key		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.logger");
	my $hash	= $self->{ $key } ||= {};
	my ($k,$v)	= @_;
	$l->trace("adding key-value " . Data::Dumper->Dump([[$k, $v]], [$key]));
	$hash->{ $k }	= $v;
}

=item C<< push_key_value ( $key, $k => $v ) >>

=cut

sub push_key_value {
	my $self	= shift;
	my $key		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.logger");
	my $hash	= $self->{ $key } ||= {};
	my ($k,$t)	= @_;
	$l->trace("pushing key-value " . Data::Dumper->Dump([[$k, $t]], [$key]));
	push( @{ $hash->{ $k } }, $t );
}

=item C<< get_value ( $key ) >>

Returns the value (not necessarily a scalar -- could be an ARRAY) for the given key.

=cut

sub get_value {
	my $self	= shift;
	my $key		= shift;
	my $value	= $self->{ $key };
	return $value;
}

=item C<< get_statistics ( $key, $subkey ) >>

Returns the average and std. dev. of the values for the given keys.

=cut

sub get_statistics {
	my $self	= shift;
	my $key		= shift;
	my $k		= shift;
	return unless (exists $self->{ $key }{ $k });
	my @values	= @{ $self->{ $key }{ $k } };
	my $sum		= 0;
	my $count	= 0;
	foreach my $v (@values) {
		$count++;
		$sum	+= $v;
	}
	my $avg	= ($sum / $count);
	
	my $stddevsum	= 0;
	foreach my $v (@values) {
		my $n	= ($v - $avg) ** 2;
		$stddevsum	+= $n;
	}
	my $stddev	= sqrt( (1 / $count) * $stddevsum );
	return ($avg, $stddev);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
