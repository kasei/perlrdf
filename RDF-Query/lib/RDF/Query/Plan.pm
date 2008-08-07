# RDF::Query::Plan
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan - Executable query plan nodes.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(blessed);

use RDF::Query::Plan::Distinct;
use RDF::Query::Plan::Filter;
use RDF::Query::Plan::Join::NestedLoop;
use RDF::Query::Plan::Offset;
use RDF::Query::Plan::Project;
use RDF::Query::Plan::Quad;
use RDF::Query::Plan::Service;
use RDF::Query::Plan::Sort;
use RDF::Query::Plan::Triple;
use RDF::Query::Plan::Union;

use constant READY		=> 0x01;
use constant OPEN		=> 0x02;
use constant CLOSED		=> 0x04;

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my @args	= @_;
	return bless( [ { __state => $class->READY }, @args ], $class );
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($);

=item C<< next >>

=cut

sub next;

=item C<< get_all >>

Returns all remaining rows.

=cut

sub get_all {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "get_all can't be called on an unopen plan";
	}
	my @rows;
	while (my $row = $self->next) {
		push(@rows, $row);
	}
	return @rows;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	$self->state( CLOSED );
}

=item C<< state ( [ $state ] ) >>

Returns the current state of the plan (either READY, OPEN, or CLOSED).
If C<< $state >> is provided, updates the plan to a new state.

=cut

sub state {
	my $self	= shift;
	if (scalar(@_)) {
		$self->[0]{__state}	= shift;
	}
	return $self->[0]{__state};
}

sub DESTROY {
	my $self	= shift;
	if ($self->state != CLOSED) {
		$self->close;
	}
}

################################################################################

=item C<< generate_plans ( $algebra ) >>

Returns a list of equivalent query plan objects for the given algebra object.

=cut

sub generate_plans {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my $algebra	= shift;
	unless (blessed($algebra) and $algebra->isa('RDF::Query::Algebra')) {
		Carp::cluck;
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan with a non-algebra object $algebra");
	}
	
	my $aclass	= ref($algebra);
	my ($type)	= ($aclass =~ m<::(\w+)$>);
	if ($type eq 'Distinct') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my @plans	= map { RDF::Query::Plan::Distinct->new( $_ ) } @base;
		return @plans;
	} elsif ($type eq 'Filter') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my $expr	= $algebra->expr;
		my @plans	= map { RDF::Query::Plan::Filter->new( $_, $expr ) } @base;
		return @plans;
	} elsif ($type eq 'BasicGraphPattern' or $type eq 'GroupGraphPattern') {
		my $method	= ($type eq 'BasicGraphPattern') ? 'triples' : 'patterns';
		my @triples	= $algebra->$method();
		if (scalar(@triples) == 1) {
			return $self->generate_plans( @triples );
		} else {
			my @base_plans	= map { [ $self->generate_plans( $_ ) ] } @triples;
			my @join_types	= RDF::Query::Plan::Join->join_classes;
			# XXX this is currently only considering left-deep trees. maybe it should produce all trees?
			my @plans		= @{ shift(@base_plans) };
			while (scalar(@base_plans)) {
				my $base_a	= [ splice( @plans ) ];
				my $base_b	= shift(@base_plans);
				foreach my $i (0 .. $#{ $base_a }) {
					foreach my $j (0 .. $#{ $base_b }) {
						my $a	= $base_a->[ $i ];
						my $b	= $base_b->[ $j ];
						foreach my $join_type (@join_types) {
							my $plan	= $join_type->new( $a, $b );
							push( @plans, $plan );
						}
					}
				}
			}
			return @plans;
		}
	} elsif ($type eq 'Limit') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my @plans	= map { RDF::Query::Plan::Limit->new( $_, $algebra->limit ) } @base;
		return @plans;
	} elsif ($type eq 'NamedGraph') {
		# XXX we should be changing triples to quads in $algebra->pattern here
		my @plans	= $self->generate_plans( $algebra->pattern );
		return @plans;
	} elsif ($type eq 'Offset') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my @plans	= map { RDF::Query::Plan::Offset->new( $_, $algebra->offset ) } @base;
		return @plans;
	} elsif ($type eq 'Optional') {
		# just like a BGP or GGP, but we have to pass the optional flag to the join constructor
		my @patterns	= ($algebra->pattern, $algebra->optional);
		my @base_plans	= map { [ $self->generate_plans( $_ ) ] } @patterns;
		# XXX make all possible join plans here (all join trees *and* all join algorithms)
		while (scalar(@base_plans) > 1) {
			my $a		= shift(@base_plans);
			my $b		= shift(@base_plans);
			my $plan	= RDF::Query::Plan::Join::NestedLoop->new( $a->[0], $b->[0], 1 );
			unshift( @base_plans, $plan );
		}
		return @base_plans;
	} elsif ($type eq 'Service') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my @plans	= map { RDF::Query::Plan::Service->new( $_, $algebra->endpoint ) } @base;
		return @plans;
	} elsif ($type eq 'Sort') {
		my @base	= $self->generate_plans( $algebra->pattern );
		my @order	= $algebra->orderby;
		my @neworder;
		foreach my $o (@order) {
			my ($dirname, $expr)	= @$o;
			my $dir	= ($dirname eq 'ASC') ? 0 : 1;
			push(@neworder, [$expr, $dir]);
		}
		my @plans	= map { RDF::Query::Plan::Sort->new( $_, @neworder ) } @base;
		return @plans;
	} elsif ($type eq 'Triple' or 'Quad') {
		my @nodes	= $algebra->nodes;
		foreach my $i (0 .. $#nodes) {
			if ($nodes[$i]->isa('RDF::Trine::Node::Blank')) {
				my $id		= $nodes[$i]->blank_identifier;
				my $name	= '__ndv_' . $id;
				$nodes[$i]	= RDF::Trine::Node::Variable->new( $name );
			}
		}
		my $pclass	= (scalar(@nodes) == 4) ? 'RDF::Query::Plan::Quad' : 'RDF::Query::Plan::Triple';
		my $plan	= $pclass->new( @nodes );
		return $plan;
	} elsif ($type eq 'Union') {
		my @plans	= map { [ $self->generate_plans( $_ ) ] } $algebra->patterns;
		# XXX
		my $plan	= RDF::Query::Plan::Union->new( map { $_->[0] } @plans );
		return $plan;
	} else {
		throw RDF::Query::Error::MethodInvocationError (-text => "Cannot generate an execution plan for unknown algebra class $aclass");
	}
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
