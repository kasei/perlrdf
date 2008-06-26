# RDF::Query::Logger
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Logger - Base class for logging objects

=head1 METHODS

=over 4

=cut

package RDF::Query::Logger;

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.002';
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
	if (@_) {
		my $value	= shift;
		local($Data::Dumper::Indent)	= 0;
		warn "setting " . Data::Dumper->Dump([$value], [$key]) if ($debug > 1);
		$self->{ $key }	= $value;
	}
	return $self->{ $key };
}

=item C<< push_value ( $key, @values ) >>

=cut

sub push_value {
	my $self	= shift;
	my $key		= shift;
	my $array	= $self->{ $key } ||= [];
	my @values	= @_;
	warn "adding values " . Data::Dumper->Dump([\@values], [$key]) if ($debug > 1);
	push( @$array, @values );
}

=item C<< add_key_value ( $key, $k => $v ) >>

=cut

sub add_key_value {
	my $self	= shift;
	my $key		= shift;
	my $hash	= $self->{ $key } ||= {};
	my ($k,$v)	= @_;
	warn "adding key-value " . Data::Dumper->Dump([[$k, $v]], [$key]) if ($debug > 1);
	$hash->{ $k }	= $v;
}

=item C<< push_key_value ( $key, $k => $v ) >>

=cut

sub push_key_value {
	my $self	= shift;
	my $key		= shift;
	my $hash	= $self->{ $key } ||= {};
	my ($k,$t)	= @_;
	warn "pushing key-value " . Data::Dumper->Dump([[$k, $t]], [$key]) if ($debug > 1);
	push( @{ $hash->{ $k } }, $t );
}


sub DESTROY {
	my $self	= shift;
	warn Dumper({ %$self }) if ($debug);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
