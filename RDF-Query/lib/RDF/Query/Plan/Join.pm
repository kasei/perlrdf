# RDF::Query::Plan::Join
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join - Join query plan base class.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Query::ExecutionContext;

=item C<< lhs >>

Returns the left-hand-side plan to the join.

=cut

sub lhs {
	my $self	= shift;
	return $self->[1];
}

=item C<< rhs >>

Returns the right-hand-side plan to the join.

=cut

sub rhs {
	my $self	= shift;
	return $self->[2];
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my @bf;
	my %var_to_num;
	my %use_count;
	my $counter	= 1;
	foreach my $t ($self->lhs, $self->rhs) {
		my $bf	= $t->bf;
		if ($bf =~ /f/) {
			$bf	= '';
			foreach my $n ($t->nodes) {
				if ($n->isa('RDF::Trine::Node::Variable')) {
					my $name	= $n->name;
					my $num		= ($var_to_num{ $name } ||= $counter++);
					$use_count{ $name }++;
					$bf	.= "{${num}}";
				} else {
					$bf	.= 'b';
				}
			}
		}
		push(@bf, $bf);
	}
	my $bf	= join(',',@bf);
	if ($counter <= 10) {
		$bf	=~ s/[{}]//g;
	}
	return $bf;
}

=item C<< join_classes >>

Returns the class names of all available join algorithms.

=cut

sub join_classes {
	my $class	= shift;
	our %JOIN_CLASSES;
	return keys %JOIN_CLASSES;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
