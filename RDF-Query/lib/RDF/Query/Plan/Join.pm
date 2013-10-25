# RDF::Query::Plan::Join
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join - Join query plan base class.

=head1 VERSION

This document describes RDF::Query::Plan::Join version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Join;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Query::ExecutionContext;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $lhs, $rhs, $optional ) >>

=cut

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	my $opt		= shift;
	my $self	= $class->SUPER::new( $lhs, $rhs, $opt, @_ );
	
	my %vars;
	my @lhs_rv	= $lhs->referenced_variables;
	my @rhs_rv	= $rhs->referenced_variables;
	foreach my $v (@lhs_rv, @rhs_rv) {
		$vars{ $v }++;
	}
	$self->[0]{referenced_variables}	= [ keys %vars ];
	return $self;
}

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

=item C<< optional >>

=cut

sub optional {
	my $self	= shift;
	return $self->[3];
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $context	= shift;
	my @bf;
	my %var_to_num;
	my %use_count;
	my $counter	= 1;
	foreach my $t ($self->lhs, $self->rhs) {
		unless ($t->can('bf')) {
			throw RDF::Query::Error::ExecutionError -text => "Cannot compute bf for $t during join";
		}
		my $bf	= $t->bf( $context );
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
	if ($counter <= 10) {
		for (@bf) {
			s/[{}]//g;
		}
	}
	my $bf	= join(',',@bf);
	return wantarray ? @bf : $bf;
}

=item C<< join_classes >>

Returns the class names of all available join algorithms.

=cut

sub join_classes {
	my $class	= shift;
	my $config	= shift || {};
	our %JOIN_CLASSES;
	my @classes	= reverse sort keys %JOIN_CLASSES;
	my @ok	= grep { 
		my $name	= lc($_);
		$name	=~ s/::/./g;
		(exists $config->{ $name } and not($config->{ $name }))
			? 0
			: 1
	} @classes;
	return @ok;
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return 0;
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(P P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $expr	= $self->[2];
	return ($self->lhs, $self->rhs);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
