# RDF::Query::Plan::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Project - Executable query plan for Projects.

=head1 VERSION

This document describes RDF::Query::Plan::Project version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Project;

use strict;
use warnings;
use Scalar::Util qw(blessed refaddr);
use base qw(RDF::Query::Plan);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( $plan, \@keys ) >>

=cut

sub new {
	my $class	= shift;
	my $plan	= shift;
	my $keys	= shift;
	my (@vars, @exprs);
	foreach my $k (@$keys) {
		push(@exprs, $k) if ($k->isa('RDF::Query::Expression'));
		push(@vars, $k->name) if ($k->isa('RDF::Query::Node::Variable'));
		push(@vars, $k) if (not(ref($k)));
	}
	my $self	= $class->SUPER::new( $plan, \@vars, \@exprs );
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PROJECT plan can't be executed while already open";
	}
	my $plan	= $self->[1];
	$plan->execute( $context );
	
	if ($plan->state == $self->OPEN) {
		$self->[0]{context}	= $context;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute plan in PROJECT";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	my $ctx		= $self->[0]{context};
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PROJECT";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.project");
	my $plan	= $self->[1];
	my $row		= $plan->next;
	unless (defined($row)) {
		$l->trace("no remaining rows in project");
# 		if ($self->[1]->state == $self->[1]->OPEN) {
# 			$self->[1]->close();
# 		}
		return;
	}
	if ($l->is_trace) {
		$l->trace( "project on row $row" );
	}
	
	my $keys	= $self->[2];
	my $exprs	= $self->[3];
	my $query	= $self->[0]{context}->query;
	my $bridge	= $self->[0]{context}->model;
	
	my $proj	= $row->project( @{ $keys } );
	foreach my $e (@$exprs) {
		my $name		= $e->sse;
		my $var_or_expr	= $e;
		my $value		= $query->var_or_expr_value( $bridge, $row, $var_or_expr, $ctx );
		if ($l->is_trace) {
			$l->trace( "- project value $name -> $value" );
		}
		$proj->{ $name }	= $value;
	}
	
	$l->trace( "- projected row: $proj" );
	if (my $d = $self->delegate) {
		$d->log_result( $self, $proj );
	}
	return $proj;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PROJECT";
	}
	delete $self->[0]{context};
	if (blessed($self->[1]) and $self->[1]->state == $self->OPEN) {
		$self->[1]->close();
	}
	$self->SUPER::close();
}

=item C<< pattern >>

Returns the query plan that will be used to produce the data to be projected.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	return $self->pattern->distinct;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	return $self->pattern->ordered;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'project';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(\J P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my @vars	= map { RDF::Query::Node::Variable->new( $_ ) } @{$self->[2]};
	my @exprs	= @{$self->[3]};
	return ([ @vars, @exprs ], $self->pattern);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	my $expr	= join(' ', @{$self->[2]}, map { blessed($_) ? $_->sse( {}, "" ) : $_ } @{$self->[3]});
	$g->add_node( "$self", label => "Project ($expr)" . $self->graph_labels );
	$g->add_edge( "$self", $c );
	return "$self";
}

=item C<< explain >>

Returns a string serialization of the plan appropriate for display on the
command line.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift || '  ';
	my $count	= shift || 0;
	my $indent	= $s x $count;
	my $type	= $self->plan_node_name;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self));
	my @vars	= map { RDF::Query::Node::Variable->new( $_ ) } @{$self->[2]};
	my @exprs	= @{$self->[3]};
	$string		.= "${indent}${s}" . join(' ', @vars, @exprs) . "\n";
	$string		.= $self->pattern->explain( $s, $count+1 );
	return $string;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
