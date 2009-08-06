# RDF::Query::Plan::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::BasicGraphPattern - Executable query plan for BasicGraphPatterns.

=head1 VERSION

This document describes RDF::Query::Plan::BasicGraphPattern version 2.200, released 6 August 2009.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::BasicGraphPattern;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);
use RDF::Trine::Statement;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200';
}

######################################################################

=item C<< new ( @triples ) >>

=cut

sub new {
	my $class	= shift;
	my @triples	= map {
					my @nodes	= $_->nodes;
					(scalar(@nodes) == 4)
						? RDF::Trine::Statement::Quad->new( @nodes )
						: RDF::Trine::Statement->new( @nodes )
				} @_;
	return $class->SUPER::new( \@triples );
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "BGP plan can't be executed twice";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.basicgraphpattern");
	$l->trace( "executing RDF::Query::Plan::BasicGraphPattern" );
	
	my @bound_triples;
	my $bound	= $context->bound;
	if (%$bound) {
		$self->[0]{bound}	= $bound;
		my @triples	= @{ $self->[1] };
		foreach my $j (0 .. $#triples) {
			my @nodes	= $triples[$j]->nodes;
			foreach my $i (0 .. $#nodes) {
				next unless ($nodes[$i]->isa('RDF::Trine::Node::Variable'));
				next unless (blessed($bound->{ $nodes[$i]->name }));
				warn "pre-bound variable found: " . $nodes[$i]->name;
				$nodes[$i]	= $bound->{ $nodes[$i]->name };
			}
			my $triple	= RDF::Trine::Statement->new( @nodes );
			push(@bound_triples, $triple);
		}
	} else {
		@bound_triples	= @{ $self->[1] };
	}
	
	my $bridge	= $context->model;
	my $iter	= $bridge->get_basic_graph_pattern( $context, @bound_triples );
	
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open BGP";
	}
	
	my $iter	= $self->[0]{iter};
	my $row		= $iter->next;
	return undef unless ($row);
	if (my $bound = $self->[0]{bound}) {
		@{ $row }{ keys %$bound }	= values %$bound;
	}
	my $result	= RDF::Query::VariableBindings->new( $row );
	return $result;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open BGP";
	}
	
	delete $self->[0]{iter};
	$self->SUPER::close();
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

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
