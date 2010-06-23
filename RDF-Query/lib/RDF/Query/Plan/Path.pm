# RDF::Query::Plan::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Path - Executable query plan for Paths.

=head1 VERSION

This document describes RDF::Query::Plan::Path version 2.900.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Path;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.900';
}

######################################################################

=item C<< new ( $op, $path, $start, $end, %args ) >>

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my $path	= shift;
	my $start	= shift;
	my $end		= shift;
	my %args	= @_;
	my $self	= $class->SUPER::new( $op, $path, $start, $end, \%args );
	my %vars;
	for ($start, $end) {
		$vars{ $_->name }++ if ($_->isa('RDF::Query::Node::Variable'));
	}
	$self->[0]{referenced_variables}	= [keys %vars];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PATH plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	$l->trace( "executing RDF::Query::Plan::Path" );
	
	my $start	= $self->start;
	my $end		= $self->end;
	my $bound	= $context->bound;
	if (%$bound) {
		for ($start, $end) {
			next unless ($_->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $_->name }));
			$_	= $bound->{ $_->name };
		}
	}
	
	$self->[0]{end}		= $end;
	$self->[0]{start}	= $start;
	$self->[0]{paths}	= [[]];
	$self->[0]{results}	= [];
	$self->[0]{bound}	= $bound;
	$self->[0]{count}	= 0;
	$self->[0]{context}	= $context;
	$self->state( $self->OPEN );
	
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PATH";
	}
	if (scalar(@{ $self->[0]{results} })) {
		return shift(@{ $self->[0]{results} });
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.path");
	my $op		= $self->op;
	while (my $p = shift(@{ $self->[0]{paths} })) {
		return shift(@{ $self->[0]{results} }) if (scalar(@{ $self->[0]{results} }));
		my @nodes	= @$p;
		if (@nodes) {
			$l->trace( 'picking up from path: (' . join('/', map { $_->sse } @nodes) . ')' );
			my $plan	= RDF::Query::Plan->__path_plan( $nodes[ $#nodes ], $self->path, $self->end, $self->[0]{context}, %{ $self->[5] } );
			$plan->execute( $self->[0]{context} );
			while (my $row = $plan->next) {
				if ($self->start->isa('RDF::Query::Node::Variable')) {
					$row->set( $self->start->name, $nodes[0] );
				}
				my $e	= ($self->end->isa('RDF::Query::Node::Variable')) ? $row->{ $self->end->name } : $self->end;
				my $ok	= 1;
				foreach my $n (@nodes) {
					$ok	= 0 if ($n->equal( $e ));
				}
				if ($ok) {
					# don't follow any loops
					push(@{ $self->[0]{paths} }, [@nodes, $e]);
				}
				push(@{ $self->[0]{results} }, $self->_add_bindings( $row ));
			}
		} else {
			if ($self->op eq '*') {
				$l->trace( 'handling zero-length paths' );
				if ($self->[0]{start}->isa('RDF::Query::Node::Variable')) {
					$l->trace( '- start of zero-length path is a variable' );
					if ($self->[0]{end}->isa('RDF::Query::Node::Variable')) {
						$l->trace( '- end of zero-length path is a variable' );
						my $plan	= RDF::Query::Plan->__zero_length_path_plan( @{ $self->[0] }{ qw(start end context) } );
						$plan->execute( $self->[0]{context} );
						while (my $row = $plan->next) {
							push(@{ $self->[0]{results} }, $self->_add_bindings( $row ));
						}
					} else {
						$l->trace( '- end of zero-length path is NOT a variable' );
						my $row	= RDF::Query::VariableBindings->new( { $self->[0]{start}->name => $self->[0]{end} } );
						push(@{ $self->[0]{results} }, $self->_add_bindings( $row ));
					}
				} elsif ($self->[0]{end}->isa('RDF::Query::Node::Variable')) {
					$l->trace( '- start of zero-length path is NOT a variable' );
					$l->trace( '- end of zero-length path is a variable' );
					warn 'start: ' . $self->[0]{start};
					my $row	= RDF::Query::VariableBindings->new( { $self->[0]{end}->name => $self->[0]{start} } );
					push(@{ $self->[0]{results} }, $self->_add_bindings( $row ));
				}
			}
			my $plan	= RDF::Query::Plan->__path_plan( $self->start, $self->path, $self->end, $self->[0]{context}, %{ $self->[5] } );
			$l->trace( 'starting path with plan: ' . $plan->sse );
			$plan->execute( $self->[0]{context} );
			while (my $row = $plan->next) {
				$l->trace("got path row: $row");
				my $s	= ($self->start->isa('RDF::Query::Node::Variable')) ? $row->{ $self->start->name } : $self->start;
				my $e	= ($self->end->isa('RDF::Query::Node::Variable')) ? $row->{ $self->end->name } : $self->end;
				push(@{ $self->[0]{paths} }, [$s,$e]);
				push(@{ $self->[0]{results} }, $self->_add_bindings( $row ));
			}
		}
	} continue {
		return shift(@{ $self->[0]{results} }) if (scalar(@{ $self->[0]{results} }));
	}
	return shift(@{ $self->[0]{results} });
}

sub _add_bindings {
	my $self		= shift;
	my $bindings	= shift;
	my $pre_bound	= $self->[0]{bound};
	@{ $bindings }{ keys %$pre_bound }	= values %$pre_bound;
	return $bindings;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PATH";
	}
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< op >>

Returns the path operation.

=cut

sub op {
	my $self	= shift;
	return $self->[1];
}

=item C<< path >>

Returns the path expression.

=cut

sub path {
	my $self	= shift;
	return $self->[2];
}

=item C<< start >>

Returns the path start node.

=cut

sub start {
	my $self	= shift;
	return $self->[3];
}

=item C<< end >>

Returns the path end node.

=cut

sub end {
	my $self	= shift;
	return $self->[4];
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
	return [];
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'path';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(s N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->op, $self->start, $self->end);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
