# RDF::Query::Algebra::NamedGraph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::NamedGraph - Algebra class for NamedGraph patterns

=head1 VERSION

This document describes RDF::Query::Algebra::NamedGraph version 2.910.

=cut

package RDF::Query::Algebra::NamedGraph;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use RDF::Query::Error;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $graph, $pattern )>

Returns a new NamedGraph structure.

=cut

sub new {
	my $class	= shift;
	my $graph	= shift;
	my $pattern	= shift;
	return bless( [ 'GRAPH', $graph, $pattern ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->graph, $self->pattern);
}

=item C<< graph >>

Returns the graph node of the named graph expression.

=cut

sub graph {
	my $self	= shift;
	if (@_) {
		my $graph	= shift;
		$self->[1]	= $graph;
	}
	my $graph	= $self->[1];
	return $graph;
}

=item C<< pattern >>

Returns the graph pattern of the named graph expression.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< quads >>

Returns a list of the quads belonging to this NamedGraph.

=cut

sub quads {
	my $self	= shift;
	my @quads;
	foreach my $p ($self->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern')) {
		push(@quads, $p->quads);
	}
	my @graphquads;
	foreach my $q (@quads) {
		my $st	= RDF::Trine::Statement::Quad->new(
					$q->subject,
					$q->predicate,
					$q->object,
					$self->graph,
				);
		push(@graphquads, $st);
	}
	return @graphquads;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '';
	
	return sprintf(
		"(namedgraph\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->graph->sse( $context, "${prefix}${indent}" ),
		$self->pattern->sse( $context, "${prefix}${indent}" )
	);
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
	my $string	= "${indent}named graph pattern\n"
				. "${indent}${s}graph: " . $self->graph->as_string . "\n"
				. $self->pattern->explain( $s, $count+1 );
	return $string;
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	my $pcontext	= { %$context, force_ggp_braces => 1 };
	
	my $string	= sprintf(
		"GRAPH %s %s",
		$self->graph->as_sparql( $context, $indent ),
		$self->pattern->as_sparql( $pcontext, $indent ),
	);
	return $string;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		graph		=> $self->graph,
		pattern		=> $self->pattern->as_hash,
	};
}

=item C<< as_spin ( $model ) >>

Adds statements to the given model to represent this algebra object in the
SPARQL Inferencing Notation (L<http://www.spinrdf.org/>).

=cut

sub as_spin {
	my $self	= shift;
	my $model	= shift;
	my $spin	= RDF::Trine::Namespace->new('http://spinrdf.org/spin#');
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my @t		= $self->pattern->as_spin( $model );
	
	my $ng		= RDF::Query::Node::Blank->new();
	my $list	= $model->add_list( @t );
	$model->add_statement( RDF::Trine::Statement->new($ng, $rdf->type, $spin->NamedGraph) );
	$model->add_statement( RDF::Trine::Statement->new($ng, $spin->elements, $list) );
	
	return $ng;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'GRAPH';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @list	= RDF::Query::_uniq(
		$self->pattern->referenced_variables,
		(map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph)),
	);
	return @list;
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @list	= RDF::Query::_uniq(
		$self->pattern->potentially_bound,
		(map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph)),
	);
	return @list;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->definite_variables,
	);
}


=item C<< qualify_uris ( \%namespaces, $base_uri ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base_uri	= shift;
	
	my $pattern	= $self->pattern->qualify_uris( $ns, $base_uri );
	my $graph	= $self->graph;
	if (blessed($graph) and $graph->isa('RDF::Query::Node::Resource')) {
		my $uri	= $graph->uri;
		if (ref($uri)) {
			my ($n,$l)	= @$uri;
			unless (exists($ns->{ $n })) {
				throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
			}
			my $resolved	= join('', $ns->{ $n }, $l);
			$graph			= RDF::Query::Node::Resource->new( $resolved, $base_uri );
		}
	}
	return $class->new( $graph, $pattern );
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@data, $arg->_referenced_blanks());
		}
	}
	
	my %seen;
	foreach my $d (@data) {
		foreach my $b (@$d) {
			if ($seen{ $b }++) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
		}
	}
	
	return 1;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
