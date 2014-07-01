# RDF::Query::Algebra::Path
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Path - Algebra class for path patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Path version 2.910.

=cut

package RDF::Query::Algebra::Path;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Set::Scalar;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $start, [ $op, @paths ], $end, $graph )>

Returns a new Path structure.

=cut

sub new {
	my $class	= shift;
	my $start	= shift;
	my $path	= shift;
	my $end		= shift;
	my $graph	= shift;
	return bless( [ $start, $path, $end, $graph ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->start, $self->path, $self->end, $self->graph);
}

=item C<< path >>

Returns the path description for this path expression.

=cut

sub path {
	my $self	= shift;
	return $self->[1];
}

=item C<< start >>

Returns the path origin node.

=cut

sub start {
	my $self	= shift;
	return $self->[0];
}

=item C<< end >>

Returns the path destination node.

=cut

sub end {
	my $self	= shift;
	return $self->[2];
}

=item C<< graph >>

Returns the named graph.

=cut

sub graph {
	my $self	= shift;
	return $self->[3];
}

=item C<< distinguish_bnode_variables >>

Returns a new Path object with blank nodes replaced by distinguished variables.

=cut

sub distinguish_bnode_variables {
	my $self	= shift;
	my $class	= ref($self);
	my @nodes	= ($self->start, $self->end);
	foreach my $i (0 .. $#nodes) {
		if ($nodes[$i]->isa('RDF::Query::Node::Blank')) {
			$nodes[$i]	= $nodes[$i]->make_distinguished_variable;
		}
	}
	return $class->new( $nodes[0], $self->path, $nodes[1] );
}

=item C<< bounded_length >>

Returns true if the path is of bounded length.

=cut

sub bounded_length {
	my $self	= shift;
	return $self->_bounded_length( $self->path );
}

sub _bounded_length {
	my $self	= shift;
	my $array	= shift;
	return 1 if blessed($array);
	my ($op, @nodes)	= @$array;
	return 1 if ($op eq '?');
	return 0 if ($op =~ /^[*+]$/);
	return 1 if ($op =~ /^\d+(-\d+)?$/);
	return 0 if ($op =~ /^\d+-$/);
	if ($op =~ m<^[/|^]$>) {
		my @fixed	= map { $self->_bounded_length($_) } @nodes;
		foreach my $f (@fixed) {
			return 0 unless ($f);
		}
		return 1;
	}
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	my $start	= $self->start->sse( $context, $prefix );
	my $end		= $self->end->sse( $context, $prefix );
	my $path	= $self->path;
	my $psse	= $self->_expand_path( $path, 'sse' );
	if ($self->graph) {
		my $graph	= $self->graph->sse( $context, $prefix );
		return sprintf( '(path %s %s %s %s)', $start, $psse, $end, $graph );
	} else {
		return sprintf( '(path %s %s %s)', $start, $psse, $end );
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent};
	my $start	= $self->start->as_sparql( $context, $prefix );
	my $end		= $self->end->as_sparql( $context, $prefix );
	my $path	= $self->path;
	my $psse	= $self->_expand_path( $path, 'as_sparql' );
	return sprintf( '%s %s %s .', $start, $psse, $end );
}

sub _expand_path {
	my $self	= shift;
	my $array	= shift;
	my $method	= shift;
	if (blessed($array)) {
		my $string	= $array->$method({}, '');
		if ($string eq '<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>') {
			return 'a';
		} else {
			return $string;
		}
	} else {
		my ($op, @nodes)	= @$array;
		my @nodessse	= map { $self->_expand_path($_, $method) } @nodes;
		my $psse;
# 		if ($op eq 'DISTINCT') {
# 			$psse	= 'DISTINCT(' . join('/', @nodessse) . ')';
# 		}
		if ($op eq '+') {
			$psse	= (scalar(@nodessse) == 1) ? $nodessse[0] . $op : '(' . join('/', @nodessse) . ')' . $op;
		} elsif ($op eq '*') {
			$psse	= (scalar(@nodessse) == 1) ? $nodessse[0] . $op : '(' . join('/', @nodessse) . ')' . $op;
		} elsif ($op eq '?') {
			$psse	= (scalar(@nodessse) == 1) ? $nodessse[0] . $op : '(' . join('/', @nodessse) . ')' . $op;
		} elsif ($op eq '!') {
			$psse	= (scalar(@nodessse) == 1) ? '!' . $nodessse[0] : '!(' . join('|', @nodessse) . ')';
		} elsif ($op eq '^') {
			$psse	= (scalar(@nodessse) == 1) ? $op . $nodessse[0] : '(' . join('/', map { "${op}$_" } @nodessse) . ')';
		} elsif ($op eq '/') {
			$psse	= (scalar(@nodessse) == 1) ? $nodessse[0] : '(' . join('/', @nodessse) . ')';
		} elsif ($op eq '|') {
			$psse	= (scalar(@nodessse) == 1) ? $nodessse[0] : '(' . join('|', @nodessse) . ')';
		} elsif ($op =~ /^(\d+)$/) {
			$psse	= join('/', @nodessse) . '{' . $op . '}';
		} elsif ($op =~ /^(\d+)-(\d+)$/) {
			$psse	= join('/', @nodessse) . "{$1,$2}";
		} elsif ($op =~ /^(\d+)-$/) {
			$psse	= join('/', @nodessse) . "{$1,}";
		} else {
			confess "Serialization of unknown path type $op";
		}
		return $psse;
	}
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'PATH';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= grep { $_->isa('RDF::Query::Node::Variable') } ($self->start, $self->end);
	return RDF::Query::_uniq(map { $_->name } @vars);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @vars	= grep { $_->isa('RDF::Query::Node::Variable') } ($self->start, $self->end);
	return RDF::Query::_uniq(map { $_->name } @vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->referenced_variables;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
