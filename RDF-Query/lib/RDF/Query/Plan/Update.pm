# RDF::Query::Plan::Update
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Update - Executable query plan for DELETE/INSERT operations.

=head1 VERSION

This document describes RDF::Query::Plan::Update version 2.918.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Update;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::Error qw(:try);
use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=item C<< new ( $delete_template, $insert_template, $pattern, \%dataset ) >>

=cut

sub new {
	my $class	= shift;
	my $delete	= shift;
	my $insert	= shift;
	my $pattern	= shift;
	my $dataset	= shift;
	my $self	= $class->SUPER::new( $delete, $insert, $pattern, $dataset );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "UPDATE plan can't be executed while already open";
	}
	
	my $insert_template	= $self->insert_template;
	my $delete_template	= $self->delete_template;
	my $plan		= $self->pattern;
	if ($self->dataset) {
		my $ds	= $context->model->dataset_model( %{ $self->dataset } );
		$context	= $context->copy( model => $ds );
	}
	$plan->execute( $context );
	if ($plan->state == $self->OPEN) {
		my $l		= Log::Log4perl->get_logger("rdf.query.plan.update");
		$l->trace( "executing RDF::Query::Plan::Update" );
		
		my @rows;
		while (my $row = $plan->next) {
			$l->trace("Update row: $row");
			push(@rows, $row);
		}
		
		my @operations	= (
			[$delete_template, 'remove_statements'],
			[$insert_template, 'add_statement'],
		);
		
		foreach my $data (@operations) {
			my ($template, $method)	= @$data;
			$l->trace("UPDATE running $method");
			foreach my $row (@rows) {
				my @triples	= blessed($template) ? $template->quads : ();
				
				TRIPLE: foreach my $t (@triples) {
					my @nodes	= $t->nodes;
					for my $i (0 .. $#nodes) {
						if ($nodes[$i]->isa('RDF::Trine::Node::Variable')) {
							my $name	= $nodes[$i]->name;
							if ($method eq 'remove_statements') {
								if (exists($row->{ $name })) {
									$nodes[$i]	= $row->{ $name };
								} else {
									next TRIPLE;
								}
							} else {
								$nodes[$i]	= $row->{ $name };
							}
						} elsif ($nodes[$i]->isa('RDF::Trine::Node::Blank')) {
							my $id	= $nodes[$i]->blank_identifier;
							unless (exists($self->[0]{blank_map}{ $id })) {
								if ($method eq 'remove_statements') {
									$self->[0]{blank_map}{ $id }	= RDF::Query::Node::Variable->new();
								} else {
									$self->[0]{blank_map}{ $id }	= RDF::Query::Node::Blank->new();
								}
							}
							$nodes[$i]	= $self->[0]{blank_map}{ $id };
						}
					}
# 					my $ok	= 1;
					foreach my $i (0 .. 3) {
						my $n	= $nodes[ $i ];
						if (not blessed($n)) {
							if ($i == 3) {
								$nodes[ $i ]	= RDF::Trine::Node::Nil->new();
							} else {
								next TRIPLE;
# 								$nodes[ $i ]	= RDF::Query::Node::Variable->new();
							}
# 							$ok	= 0;
# 						} elsif ($n->isa('RDF::Trine::Node::Variable')) {
# 							$ok	= 0;
						}
					}
# 					next unless ($ok);
					my $st	= (scalar(@nodes) == 4)
							? RDF::Trine::Statement::Quad->new( @nodes )
							: RDF::Trine::Statement->new( @nodes );
					$l->trace( "$method: " . $st->as_string );
					if ($method eq 'remove_statements') {
						$context->model->$method( $st->nodes );
					} else {
						$context->model->$method( $st );
					}
				}
			}
		}
		$self->[0]{ok}	= 1;
		$self->state( $self->OPEN );
	} else {
		warn "could not execute Update pattern plan";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open UPDATE";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.update");
	$self->close();
	if (my $d = $self->delegate) {
		$d->log_result( $self, $self->[0]{ok} );
	}
	return $self->[0]{ok};
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open UPDATE";
	}
	
	delete $self->[0]{ok};
	$self->SUPER::close();
}

=item C<< delete_template >>

Returns the algebra object representing the RDF template to delete.

=cut

sub delete_template {
	my $self	= shift;
	return $self->[1];
}

=item C<< insert_template >>

Returns the algebra object representing the RDF template to insert.

=cut

sub insert_template {
	my $self	= shift;
	return $self->[2];
}

=item C<< pattern >>

Returns the pattern plan object.

=cut

sub pattern {
	my $self	= shift;
	return $self->[3];
}

=item C<< dataset >>

Returns the dataset HASH reference.

=cut

sub dataset {
	my $self	= shift;
	return $self->[4];
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
	return 'update';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(A A P);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	return ($self->delete_template, $self->insert_template, $self->pattern);
}

=item C<< explain >>

Returns a string serialization of the algebra appropriate for display on the
command line.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $type	= $self->plan_node_name;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self));
	
	if (my $d = $self->delete_template) {
		$string	.= "${indent}${s}delete:\n";
		$string	.= $d->explain( $s, $count+2 );
	}

	if (my $i = $self->insert_template) {
		$string	.= "${indent}${s}insert:\n";
		$string	.= $i->explain( $s, $count+2 );
	}

	if (my $p = $self->pattern) {
		if ($p->isa('RDF::Query::Plan::Constant') and $p->is_unit) {
			
		} else {
			$string	.= "${indent}${s}where:\n";
			$string	.= $p->explain( $s, $count+2 );
		}
	}
	
	return $string;
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	my $url		= $self->url->uri_value;
	throw RDF::Query::Error::ExecutionError -text => "RDF::Query::Plan::Update->graph not implemented.";
# 	$g->add_node( "$self", label => "delete" . $self->graph_labels );
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
