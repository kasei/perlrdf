# RDF::Query::Plan::Insert
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Insert - Executable query plan for INSERT operations.

=head1 VERSION

This document describes RDF::Query::Plan::Insert version 2.202, released 30 January 2010.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Insert;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::Error qw(:try);
use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.202';
}

######################################################################

=item C<< new ( $template, $pattern ) >>

=cut

sub new {
	my $class	= shift;
	my $temp	= shift;
	my $pattern	= shift;
	my $self	= $class->SUPER::new( $temp, $pattern );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "INSERT plan can't be executed while already open";
	}
	
	my $template	= $self->template;
	my $plan		= $self->pattern;
	$plan->execute( $context );
	if ($plan->state == $self->OPEN) {
		my $l		= Log::Log4perl->get_logger("rdf.query.plan.insert");
		$l->trace( "executing RDF::Query::Plan::Insert" );
		
		while (my $row = $plan->next) {
			my (@triples, $graph);
			if ($template->isa('RDF::Query::Algebra::BasicGraphPattern')) {
				@triples	= $template->triples;
			} else {
				@triples	= ($template->pattern->patterns)[0]->triples;
				$graph		= $template->graph;
			}
			
			foreach my $t (@triples) {
				if ($l->is_debug) {
					$l->debug( "- filling-in construct triple pattern: " . $t->as_string );
				}
				my @triple	= $t->nodes;
				for my $i (0 .. 2) {
					if ($triple[$i]->isa('RDF::Trine::Node::Variable')) {
						my $name	= $triple[$i]->name;
						$triple[$i]	= $row->{ $name };
					} elsif ($triple[$i]->isa('RDF::Trine::Node::Blank')) {
						my $id	= $triple[$i]->blank_identifier;
						unless (exists($self->[0]{blank_map}{ $id })) {
							$self->[0]{blank_map}{ $id }	= RDF::Trine::Node::Blank->new();
						}
						$triple[$i]	= $self->[0]{blank_map}{ $id };
					}
				}
				my $ok	= 1;
				foreach (@triple) {
					if (not blessed($_)) {
						$ok	= 0;
					} elsif ($_->isa('RDF::Trine::Node::Variable')) {
						$ok	= 0;
					}
				}
				next unless ($ok);
				my $st	= ($graph)
						? RDF::Trine::Statement::Quad->new( @triple[0..2], $graph )
						: RDF::Trine::Statement->new( @triple );
				$context->model->add_statement( $st );
			}
		}
		$self->[0]{ok}	= 1;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute Insert pattern plan";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open INSERT";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.insert");
	$self->close();
	return $self->[0]{ok};
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open INSERT";
	}
	
	delete $self->[0]{ok};
	$self->SUPER::close();
}

=item C<< template >>

Returns the algebra object representing the RDF template to insert.

=cut

sub template {
	my $self	= shift;
	return $self->[1];
}

=item C<< pattern >>

Returns the pattern plan object.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 1;
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
	return 'insert';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(A P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->template, $self->pattern);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	my $url		= $self->url->uri_value;
	die;
# 	$g->add_node( "$self", label => "Insert" . $self->graph_labels );
# 	$g->add_node( "${self}$url", label => $url );
# 	$g->add_edge( "$self" => "${self}$url", label => 'url' );
# 	return "$self";
}

=item C<< is_update >>

Returns true if the plan represents an update operation.

=cut

sub is_update {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
