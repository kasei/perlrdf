# RDF::Query::Plan::Quad
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Quad - Executable query plan for Quads.

=head1 VERSION

This document describes RDF::Query::Plan::Quad version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Quad;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed refaddr);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=item C<< new ( @quad ) >>

=cut

sub new {
	my $class	= shift;
	my @quad	= @_;
	my $self	= $class->SUPER::new( @quad );
	
	### the next two loops look for repeated variables because some backends
	### can't distinguish a pattern like { ?a ?a ?b }
	### from { ?a ?b ?c }. if we find repeated variables (there can be at most
	### two since there are only four nodes in a quad), we save the positions
	### in the quad that hold the variable(s), and the code in next() will filter
	### out any results that don't have the same value in those positions.
	###
	### in the first pass, we also set up the mapping that will let us pull out
	### values from the result quads to construct result bindings.
	
	my %var_to_position;
	my @methodmap	= qw(subject predicate object context);
	my %counts;
	my @dup_vars;
	foreach my $idx (0 .. 3) {
		my $node	= $quad[ $idx ];
		if (blessed($node) and $node->isa('RDF::Trine::Node::Variable')) {
			my $name	= $node->name;
			$var_to_position{ $name }	= $methodmap[ $idx ];
			$counts{ $name }++;
			if ($counts{ $name } >= 2) {
				push(@dup_vars, $name);
			}
		}
	}
	$self->[0]{referenced_variables}	= [ keys %counts ];
	
	my %positions;
	if (@dup_vars) {
		foreach my $dup_var (@dup_vars) {
			foreach my $idx (0 .. 3) {
				my $var	= $quad[ $idx ];
				if (blessed($var) and ($var->isa('RDF::Trine::Node::Variable') or $var->isa('RDF::Trine::Node::Blank'))) {
					my $name	= ($var->isa('RDF::Trine::Node::Blank')) ? '__' . $var->blank_identifier : $var->name;
					if ($name eq $dup_var) {
						push(@{ $positions{ $dup_var } }, $methodmap[ $idx ]);
					}
				}
			}
		}
	}
	
	$self->[0]{mappings}	= \%var_to_position;
	
	if (%positions) {
		$self->[0]{dups}	= \%positions;
	}
	
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "QUAD plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.quad");
	$l->trace( "executing RDF::Query::Plan::Quad:" );
	
	my @quad	= @{ $self }[ 1..4 ];
	my $bound	= $context->bound;
	if (%$bound) {
		foreach my $i (0 .. $#quad) {
			next unless ($quad[$i]->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $quad[$i]->name }));
			$quad[ $i ]	= $bound->{ $quad[$i]->name };
		}
	}
	
	my $model	= $context->model;
	
	my @names	= qw(subject predicate object context);
	foreach my $i (0 .. 3) {
		$l->trace( sprintf("- quad %10s: %s", $names[$i], $quad[$i]) );
	}
	
	my $iter	= $model->get_statements( @quad[0..3] );
	if (blessed($iter)) {
		$l->trace("got quad iterator");
		$self->[0]{iter}	= $iter;
		$self->[0]{bound}	= $bound;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open QUAD";
	}
	my $iter	= $self->[0]{iter};
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.quad");
	$l->trace("next() called on Quad plan");
	LOOP: while (my $row = $iter->next) {
		$l->trace("got quad: " . $row->as_string);
		if (my $data = $self->[0]{dups}) {
			foreach my $pos (values %$data) {
				my @pos	= @$pos;
				my $first_method	= shift(@pos);
				my $first			= $row->$first_method();
				foreach my $p (@pos) {
					unless ($first->equal( $row->$p() )) {
						use Data::Dumper;
						$l->trace("Quad $first_method and $p didn't match: " . Dumper($first, $row->$p()));
						next LOOP;
					}
				}
			}
		}
		
# 		if ($row->context->isa('RDF::Trine::Node::Nil')) {
# 			next;
# 		}
		
		my $binding	= {};
		foreach my $key (keys %{ $self->[0]{mappings} }) {
			my $method	= $self->[0]{mappings}{ $key };
			$binding->{ $key }	= $row->$method();
		}
		my $pre_bound	= $self->[0]{bound};
		my $bindings	= RDF::Query::VariableBindings->new( $binding );
		if ($row->can('label')) {
			if (my $o = $row->label('origin')) {
				$bindings->label( origin => [ $o ] );
			}
		}
		@{ $bindings }{ keys %$pre_bound }	= values %$pre_bound;
		if (my $d = $self->delegate) {
			$d->log_result( $self, $bindings );
		}
		return $bindings;
	}
	$l->trace("No more quads");
	return;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		Carp::cluck;
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open QUAD";
	}
	delete $self->[0]{iter};
	delete $self->[0]{bound};
	$self->SUPER::close();
}

=item C<< nodes () >>

=cut

sub nodes {
	my $self	= shift;
	return @{ $self }[1,2,3,4];
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $context	= shift;
	my $bf		= '';
	my $bound	= $context->bound;
	foreach my $n (@{ $self }[1,2,3,4]) {
		if ($n->isa('RDF::Trine::Node::Variable')) {
			if (my $b = $bound->{ $n->name }) {
				$bf	.= 'b';
			} else {
				$bf	.= 'f';
			}
		} else {
			$bf	.= 'b';
		}
	}
	return $bf;
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
	return 'quad';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(N N N N);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->nodes);
}

=item C<< explain >>

Returns a string serialization of the query plan appropriate for display
on the command line.

=cut

sub explain {
	my $self	= shift;
	my ($s, $count)	= ('  ', 0);
	if (@_) {
		$s		= shift;
		$count	= shift;
	}
	my $indent	= '' . ($s x $count);
	my $type	= $self->plan_node_name;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self))
				. "${indent}${s}"
				. join(' ', map { ($_->isa('RDF::Trine::Node::Nil')) ? "(nil)" : $_->as_sparql } $self->plan_node_data) . "\n";
	return $string;
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	$g->add_node( "$self", label => "Quad" . $self->graph_labels );
	my @names	= qw(subject predicate object context);
	foreach my $i (0 .. 3) {
		my $n	= $self->[ $i + 1 ];
		my $rel	= $names[ $i ];
		my $str	= $n->sse( {}, '' );
		$g->add_node( "${self}$n", label => $str );
		$g->add_edge( "$self" => "${self}$n", label => $names[ $i ] );
	} 
	return "$self";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
