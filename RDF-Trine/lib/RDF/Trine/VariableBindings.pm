# RDF::Trine::VariableBindings
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::VariableBindings - Variable bindings

=head1 VERSION

This document describes RDF::Trine::VariableBindings version 1.012

=head1 SYNOPSIS

  use RDF::Trine qw(literal);
  use RDF::Trine::VariableBindings;
  my $vb = RDF::Trine::VariableBindings->new( {} );
  $vb->set( foo => literal("bar") );
  $vb->set( baz => literal("blee") );
  $vb->variables; # qw(foo baz)
  
  my $x = RDF::Trine::VariableBindings->new( { foo => literal("bar") } );
  $x->set( greeting => literal("hello") );

  my $j = $vb->join( $x ); # { foo => "bar", baz => "blee", greeting => "hello" }

  my @keys = qw(baz greeting);
  my $p = $j->project( @keys ); # { baz => "blee", greeting => "hello" }
  print $p->{greeting}->literal_value; # "hello"

=head1 DESCRIPTION

RDF::Trine::VariableBindings objects provide a mapping from variable names to
RDF::Trine::Node objects. The objects may be used as a hash reference, with
variable names used as hash keys.

=head1 METHODS

=over 4

=cut

package RDF::Trine::VariableBindings;

use strict;
use warnings;
use overload	'""'	=> sub { $_[0]->as_string };

my %VB_LABELS;

use Scalar::Util qw(blessed refaddr);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=item C<< new ( \%bindings ) >>

=cut

sub new {
	my $class		= shift;
	my $bindings	= shift;
	my $self		= bless( { %$bindings }, $class );
	
	if (blessed($bindings) and $bindings->isa('RDF::Trine::VariableBindings')) {
		my $addr	= refaddr($bindings);
		if (ref($VB_LABELS{ $addr })) {
			$VB_LABELS{ refaddr($self) }	= { %{ $VB_LABELS{ $addr } } };
		}
	}
	
	return $self;
}

=item C<< set ( $variable_name => $node ) >>

=cut

sub set {
	my $self	= shift;
	my $name	= shift;
	my $node	= shift;
	$self->{ $name }	= $node;
}

=item C<< join ( $row ) >>

Returns a new VariableBindings object based on the join of this object and C<< $row >>.
If the two variable binding objects cannot be joined, returns undef.

=cut

sub join {
	my $self	= shift;
	my $class	= ref($self);
	my $rowb	= shift;
	
	my %keysa;
	my @keysa	= keys %$self;
	@keysa{ @keysa }	= (1) x scalar(@keysa);
	my @shared	= grep { exists $keysa{ $_ } } (keys %$rowb);
	foreach my $key (@shared) {
		my $val_a	= $self->{ $key };
		my $val_b	= $rowb->{ $key };
		next unless (defined($val_a) and defined($val_b));
		my $equal	= (refaddr($val_a) == refaddr($val_b)) || ($val_a == $val_b) || $val_a->equal( $val_b );
		unless ($equal) {
			return;
		}
	}
	
	my $row	= { (map { $_ => $self->{$_} } grep { defined($self->{$_}) } keys %$self), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
	my $joined	= $class->new( $row );
	$joined->copy_labels_from( $self );
	$joined->copy_labels_from( $rowb );
	
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

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
