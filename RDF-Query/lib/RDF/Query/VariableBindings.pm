# RDF::Query::VariableBindings
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::VariableBindings - Variable bindings

=head1 VERSION

This document describes RDF::Query::VariableBindings version 2.200_01, released XX July 2009.

=head1 METHODS

=over 4

=cut

package RDF::Query::VariableBindings;

use strict;
use warnings;
use overload	'""'	=> sub { $_[0]->as_string };

my %VB_LABELS;

use Scalar::Util qw(blessed refaddr);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200_01';
}

######################################################################

=item C<< new ( \%bindings ) >>

=cut

sub new {
	my $class		= shift;
	my $bindings	= shift;
	my $self		= bless( { %$bindings }, $class );
	foreach my $k (keys %$self) {
		my $node	= $self->{$k};
		if (ref($node) and not($node->isa('RDF::Query::Node'))) {
			$self->{$k}	= RDF::Query::Node->from_trine( $node );
		}
	}
	
	if (blessed($bindings) and $bindings->isa('RDF::Query::VariableBindings')) {
		my $addr	= refaddr($bindings);
		if (ref($VB_LABELS{ $addr })) {
			$VB_LABELS{ refaddr($self) }	= { %{ $VB_LABELS{ $addr } } };
		}
	}
	
	return $self;
}

=item C<< copy_labels_from ( $vb ) >>

Copies the labels from C<< $vb >>, adding them to the labels for this object.

=cut

sub copy_labels_from {
	my $self		= shift;
	my $rowa		= shift;
	my $self_labels	= $VB_LABELS{ refaddr($self) };
	my $a_labels	= $VB_LABELS{ refaddr($rowa) };
	if ($self_labels or $a_labels) {
		$self_labels	||= {};
		$a_labels		||= {};
		my %new_labels	= ( %$self_labels, %$a_labels );
		
		if (exists $new_labels{'origin'}) {
			my %origins;
			foreach my $o (@{ $self_labels->{'origin'} || [] }) {
				$origins{ $o }++;
			}
			foreach my $o (@{ $a_labels->{'origin'} || [] }) {
				$origins{ $o }++;
			}
			$new_labels{'origin'}	= [ keys %origins ];
		}
		
		$VB_LABELS{ refaddr($self) }	= \%new_labels;
	}
}

=item C<< join ( $row ) >>

Returns a new VariableBindings object based on the join of this object and C<< $row >>.
If the two variable binding objects cannot be joined, returns undef.

=cut

sub join {
	my $self	= shift;
	my $class	= ref($self);
	my $rowa	= shift;
	
	my %keysa;
	my @keysa	= keys %$self;
	@keysa{ @keysa }	= (1) x scalar(@keysa);
	my @shared	= grep { exists $keysa{ $_ } } (keys %$rowa);
	foreach my $key (@shared) {
		my $val_a	= $self->{ $key };
		my $val_b	= $rowa->{ $key };
		next unless (defined($val_a) and defined($val_b));
		my $equal	= $val_a->equal( $val_b );
		unless ($equal) {
			return undef;
		}
	}
	
	my $row	= { (map { $_ => $self->{$_} } grep { defined($self->{$_}) } keys %$self), (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa) };
	my $joined	= $class->new( $row );
	$joined->copy_labels_from( $self );
	$joined->copy_labels_from( $rowa );
	
	return $joined;
}

=item C<< variables >>

=cut

sub variables {
	my $self	= shift;
	return (keys %$self);
}

=item C<< project ( @keys ) >>

Returns a new binding with values for only the keys listed.

=cut

sub project {
	my $self	= shift;
	my $class	= ref($self);
	my @keys	= @_;
	my %data	= map { $_ => $self->{ $_ } } @keys;
	my $p		= $class->new( \%data );
	
	my $addr	= refaddr($self);
	if (ref($VB_LABELS{ $addr })) {
		$VB_LABELS{ refaddr($p) }	= { %{ $VB_LABELS{ $addr } } };
	}
	
	return $p;
}

=item C<< as_string >>

Returns a string representation of the variable bindings.

=cut

sub as_string {
	my $self	= shift;
	my @keys	= sort keys %$self;
	my $string	= sprintf('{ %s }', CORE::join(', ', map { CORE::join('=', $_, ($self->{$_}) ? $self->{$_}->as_string : '()') } (@keys)));
	return $string;
}

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	my @keys	= sort keys %$self;
	return sprintf('(row %s)', CORE::join(' ', map { '[' . CORE::join(' ', '?' . $_, ($self->{$_}) ? $self->{$_}->as_string : ()) . ']' } (@keys)));
}

=item C<< label ( $label => $value ) >>

Sets the named C<< $label >> to C<< $value >> for this variable bindings object.
If no C<< $value >> is given, returns the current label value, or undef if none
exists.

=cut

sub label {
	my $self	= shift;
	my $addr	= refaddr($self);
	my $label_name	= shift;
	if (@_) {
		my $value	= shift;
		$VB_LABELS{ $addr }{ $label_name }	= $value;
	}
	
	my $labels	= $VB_LABELS{ $addr };
	if (ref($labels)) {
		my $value	= $labels->{ $label_name };
		return $value;
	} else {
		return;
	}
}

sub _labels {
	my $self	= shift;
	my $addr	= refaddr($self);
	my $labels	= $VB_LABELS{ $addr };
	return $labels;
}

sub DESTROY {
	my $self	= shift;
	my $addr	= refaddr( $self );
	delete $VB_LABELS{ $addr };
	return;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
