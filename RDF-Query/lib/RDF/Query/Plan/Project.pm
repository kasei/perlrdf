# RDF::Query::Plan::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Project - Executable query plan for Projects.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Project;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

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
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
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
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PROJECT";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.project");
	my $plan	= $self->[1];
	my $row		= $plan->next;
	return undef unless ($row);
	$l->debug( "project on row $row" );
	
	my $keys	= $self->[2];
	my $exprs	= $self->[3];
	my $query	= $self->[0]{context}->query;
	my $bridge	= $self->[0]{context}->model;
	
	my $proj	= $row->project( @{ $keys } );
	foreach my $e (@$exprs) {
		my $var_or_expr;
		my $name;
		if ($e->isa('RDF::Query::Expression::Alias')) {
			$name			= $e->name;
			$var_or_expr	= $e->expression;
			$l->debug( "- project alias " . $var_or_expr->sse . " -> $name" );
		} else {
			$name			= $e->sse;
			$var_or_expr	= $e;
		}
		my $value		= $query->var_or_expr_value( $bridge, $row, $var_or_expr );
		$l->debug( "- project value $name -> $value" );
		$proj->{ $name }	= $value;
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
	$self->[1]->close();
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

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	my $vars	= join(' ',
					@{$self->[2]},
					map { $_->sse( $context, "${indent}${more}" ) } @{$self->[3]}
				);
	return sprintf("(project (%s)\n${indent}${more}%s\n${indent})", $vars, $self->pattern->sse( $context, "${indent}${more}" ));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $c		= $self->pattern->graph( $g );
	my $expr	= join(' ', @{$self->[1]}, map { $_->sse( {}, "" ) } @{$self->[2]});
	$g->add_node( "$self", label => "Project ($expr)" );
	$g->add_edge( "$self", $c );
	return "$self";
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
