# RDF::Query::Model::RDFTrine::BasicGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model::RDFTrine::BasicGraphPattern - Plan class for BasicGraphPattern patterns

=head1 VERSION

This document describes RDF::Query::Model::RDFTrine::BasicGraphPattern version 2.201, released 30 January 2010.

=cut

package RDF::Query::Model::RDFTrine::BasicGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);
use RDF::Trine::Statement;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.201';
}

######################################################################

=head1 METHODS

=over 4

=cut

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
	my %vars;
	foreach my $t (@triples) {
		$vars{ $_ }++ foreach ($t->referenced_variables);
	}
	my $self	= $class->SUPER::new( \@triples );
	$self->[0]{referenced_variables}	= [ keys %vars ];
	return $self;
}

=item C<< triples >>

=cut

sub triples {
	my $self	= shift;
	return @{ $self->[1] };
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "RDFTrine BGP plan can't be executed twice";
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
# 				warn "pre-bound variable found: " . $nodes[$i]->name;
				$nodes[$i]	= $bound->{ $nodes[$i]->name };
			}
			my $triple	= (scalar(@nodes) == 4)
						? RDF::Trine::Statement::Quad->new( @nodes )
						: RDF::Trine::Statement->new( @nodes );
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
	return $self;
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

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf(
		"(rdftrine-BGP\n${indent}${indent}%s)",
		join("\n${indent}${indent}", map { $_->sse( $context ) } $self->triples)
	);
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

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my $label	= $self->graph_labels;
	
	$g->add_node( "$self", label => "BasicGraphPattern (RDF::Trine)" . $self->graph_labels );
	
	my @triples	= $self->triples;
	foreach my $t (@triples) {
		$g->add_node( "$t", label => "Triple" );
		$g->add_edge( "$self" => "$t" );
		my @names	= qw(subject predicate object);
		foreach my $i (0 .. 2) {
			my $rel	= $names[ $i ];
			my $n	= $t->$rel();
			my $str	= $n->sse( {}, '' );
			if (0) {	# this will use shared vertices for the nodes of all the BGP's triples (but can result in dense, complex graphs
				$g->add_node( "${self}$str", label => $str );
				$g->add_edge( "$t" => "${self}$str", label => $names[ $i ] );
			} else {
				$g->add_node( "${self}${t}$n", label => $str );
				$g->add_edge( "$t" => "${self}${t}$n", label => $names[ $i ] );
			}
		}
	}
	return "$self";
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
