# RDF::Query::VariableBindings
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::VariableBindings - Variable bindings

=head1 METHODS

=over 4

=cut

package RDF::Query::VariableBindings;

use strict;
use warnings;
use overload	'""'	=> sub { $_[0]->as_string },
			;

use Scalar::Util qw(blessed);

=item C<< new ( \%bindings ) >>

=cut

sub new {
	my $class		= shift;
	my $bindings	= shift;
	my $self		= bless( { %$bindings }, $class );
	return $self;
}

=item C<< join ( $row ) >>

Returns a new VariableBindings object based on the join of this object and C<< $row >>.
If the two variable binding objects cannot be joined, returns undef.

=cut

sub join {
	my $self	= shift;
	my $class	= ref($self);
	my $rowa	= shift;
	
	my %keysa	= map {$_=>1} (keys %$self);
	my @shared	= grep { $keysa{ $_ } } (keys %$rowa);
	foreach my $key (@shared) {
		my $val_a	= $self->{ $key };
		my $val_b	= $rowa->{ $key };
		my $defined	= 0;
		foreach my $n ($val_a, $val_b) {
			$defined++ if (defined($n));
		}
		if ($defined == 2) {
			my $equal	= $val_a->equal( $val_b );
			unless ($equal) {
				return undef;
			}
		}
	}
	
	my $row	= { (map { $_ => $self->{$_} } grep { defined($self->{$_}) } keys %$self), (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa) };
	return $class->new( $row );
}

=item C<< as_string >>

Returns a string representation of the variable bindings.

=cut

sub as_string {
	my $self	= shift;
	my @keys	= keys %$self;
	my $string	= sprintf('{ %s }', CORE::join(', ', map { CORE::join('=', $_, ($self->{$_}) ? $self->{$_}->as_string : '(undef)') } (@keys)));
	return $string;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
