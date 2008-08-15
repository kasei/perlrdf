# RDF::Query::Federate::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Federate::Plan - Executable query plan nodes.

=head1 METHODS

=over 4

=cut

package RDF::Query::Federate::Plan;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Data::Dumper;
use Scalar::Util qw(blessed);
use RDF::Query::Error qw(:try);

=item C<< generate_plans ( $algebra, $execution_context, %args ) >>

Returns a list of equivalent query plan objects for the given algebra object.

=cut

sub generate_plans {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my $algebra	= shift;
	my $context	= shift;
	my $model	= $context->model;
	my %args	= @_;
	unless (blessed($algebra) and $algebra->isa('RDF::Query::Algebra')) {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan with a non-algebra object $algebra");
	}
	
	my @return_plans;
	my $aclass	= ref($algebra);
	my ($type)	= ($aclass =~ m<::(\w+)$>);
	if ($type eq 'BasicGraphPattern') {
		my @base_plans	= map { [ $self->generate_plans( $_, $context, %args ) ] } $algebra->triples;
		my @join_types	= RDF::Query::Plan::Join->join_classes;
		# XXX this is currently only considering left-deep trees. maybe it should produce all trees?
		my @plans		= @{ shift(@base_plans) };
		while (scalar(@base_plans)) {
			my $base_a	= [ splice( @plans ) ];
			my $base_b	= shift(@base_plans);
			foreach my $i (0 .. $#{ $base_a }) {
				my ($sd, $algebra, $plan)	= @{ $base_a->[$i] };
				foreach my $j (0 .. $#{ $base_b }) {
					my $a	= $base_a->[ $i ];
					my $b	= $base_b->[ $j ];
					foreach my $join_type (@join_types) {
						try {
							my $plan	= $join_type->new( $a, $b );
							push( @plans, $plan );
						} catch RDF::Query::Error::MethodInvocationError with {
#								warn "caught MethodInvocationError.";
						};
					}
				}
			}
		}
		@return_plans	= @plans;
	} elsif ($type eq 'Triple') {
		my $query	= $context->query;
		my @sds		= $query->services;
		my @base	= $self->SUPER::generate_plans( $algebra, $context );
		foreach my $p (@base) {
			foreach my $sd (@sds) {
				push(@return_plans, [ $sd, $algebra, $p ]);
			}
		}
	} else {
		return $self->SUPER::generate_plans( $algebra, $context, %args );
	}
	
	return @return_plans;
}

sub _add_constant_join {
	my $self		= shift;
	my $constant	= shift;
	my @return_plans	= @_;
	my @join_types	= RDF::Query::Plan::Join->join_classes;
	while (my $const = shift(@$constant)) {
		my @plans	= splice(@return_plans);
		foreach my $p (@plans) {
			foreach my $join_type (@join_types) {
				try {
					my $plan	= $join_type->new( $p, $const );
					push( @return_plans, $plan );
				} catch RDF::Query::Error::MethodInvocationError with {
	#						warn "caught MethodInvocationError.";
				};
			}
		}
	}
	return @return_plans;
}

sub _make_blank_distinguished_variable {
	my $blank	= shift;
	my $id		= $blank->blank_identifier;
	my $name	= '__ndv_' . $id;
	my $var		= RDF::Trine::Node::Variable->new( $name );
	return $var;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
