# RDF::Query::Plan::Triple
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Triple - Executable query plan for Triples.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Triple;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Log::Log4perl;
use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( @triple ) >>

=cut

sub new {
	my $class	= shift;
	my @triple	= splice(@_, 0, 3);
	my $keys	= shift || {};
	my $self	= $class->SUPER::new( @triple );
	$self->[0]{logging_keys}	= $keys;
	
	### the next two loops look for repeated variables because some backends
	### (Redland and RDF::Core) can't distinguish a pattern like { ?a ?a ?b }
	### from { ?a ?b ?c }. if we find repeated variables (there can be at most
	### one since there are only three nodes in a triple), we save the positions
	### in the triple that hold the variable, and the code in next() will filter
	### out any results that don't have the same value in those positions.
	###
	### in the first pass, we also set up the mapping that will let us pull out
	### values from the result triples to construct result bindings.
	
	my %var_to_position;
	my @methodmap	= qw(subject predicate object);
	my %counts;
	my $dup_var;
	foreach my $idx (0 .. 2) {
		my $node	= $triple[ $idx ];
		if (blessed($node) and $node->isa('RDF::Trine::Node::Variable')) {
			my $name	= $node->name;
			$var_to_position{ $name }	= $methodmap[ $idx ];
			$counts{ $name }++;
			if ($counts{ $name } >= 2) {
				$dup_var	= $name;
			}
		}
	}
	$self->[0]{referenced_variables}	= [ keys %counts ];
	
	my @positions;
	if (defined($dup_var)) {
		foreach my $idx (0 .. 2) {
			my $var	= $triple[ $idx ];
			if (blessed($var) and $var->isa('RDF::Trine::Node::Variable')) {
				my $name	= $var->name;
				if ($name eq $dup_var) {
					push(@positions, $methodmap[ $idx ]);
				}
			}
		}
	}
	
	$self->[0]{mappings}	= \%var_to_position;
	
	if (@positions) {
		$self->[0]{dups}	= \@positions;
	}
	
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "TRIPLE plan can't be executed while already open";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	$l->trace( "executing RDF::Query::Plan::Triple" );
	
	$self->[0]{start_time}	= [gettimeofday];
	my @triple	= @{ $self }[ 1,2,3 ];
	my $bound	= $context->bound;
	if (%$bound) {
		foreach my $i (0 .. $#triple) {
			next unless ($triple[$i]->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $triple[$i]->name }));
			$triple[ $i ]	= $bound->{ $triple[$i]->name };
		}
	}
	
	my $bridge	= $context->model;
	my $iter	= $bridge->get_statements( @triple, $context->query, $context->bound );
	
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->[0]{bound}	= $bound;
		$self->[0]{logger}	= $context->logger;
		$self->[0]{count}	= 0;
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
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open TRIPLE";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	my $iter	= $self->[0]{iter};
	LOOP: while (my $row = $iter->next) {
		$l->trace( "- got triple from model: " . $row->as_string );
		if (my $pos = $self->[0]{dups}) {
			$l->trace( "- checking for duplicate variables in triple" );
			my @pos	= @$pos;
			my $first_method	= shift(@pos);
			my $first			= $row->$first_method();
			foreach my $p (@pos) {
				unless ($first->equal( $row->$p() )) {
					next LOOP;
				}
			}
		}
		
		my $binding	= {};
		foreach my $key (keys %{ $self->[0]{mappings} }) {
			my $method	= $self->[0]{mappings}{ $key };
			$binding->{ $key }	= $row->$method();
		}
		my $pre_bound	= $self->[0]{bound};
		my $bindings	= RDF::Query::VariableBindings->new( $binding );
		@{ $bindings }{ keys %$pre_bound }	= values %$pre_bound;
		$self->[0]{count}++;
		return $bindings;
	}
	return;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		Carp::cluck;
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open TRIPLE";
	}
	
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.triple");
	my $t0		= delete $self->[0]{start_time};
	my $count	= delete $self->[0]{count};
	if (my $log = delete $self->[0]{logger}) {
		$l->debug("logging triple execution statistics");
		my $elapsed = tv_interval ( $t0 );
		if (my $sparql = $self->logging_keys->{sparql}) {
			$l->debug("- SPARQL: $sparql");
			$log->push_key_value( 'execute_time-triple', $sparql, $elapsed );
			$log->push_key_value( 'cardinality-triple', $sparql, $count );
			$l->debug("- elapsed: $elapsed");
			$l->debug("- count: $count");
		}
		if (my $bf = $self->logging_keys->{bf}) {
			$l->debug("- cardinality-bf-triple: $bf: $count");
			$log->push_key_value( 'cardinality-bf-triple', $bf, $count );
		}
	}
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< nodes () >>

=cut

sub nodes {
	my $self	= shift;
	return @{ $self }[1,2,3];
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $context	= shift;
	my $bf		= '';
	my $bound	= $context->bound;
	foreach my $n (@{ $self }[1,2,3]) {
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

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf("(triple %s %s %s)", map { $_->sse( $context, "${indent}${more}" ) } @{ $self }[1..3]);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	$g->add_node( "$self", label => "Triple" );
	my @names	= qw(subject predicate object);
	foreach my $i (0 .. 2) {
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
