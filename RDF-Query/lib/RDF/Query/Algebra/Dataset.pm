# RDF::Query::Algebra::Dataset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Dataset - Algebra class for dataset declarations

=head1 VERSION

This document describes RDF::Query::Algebra::Dataset version 2.202, released 30 January 2010.

=cut

package RDF::Query::Algebra::Dataset;

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
	$VERSION	= '2.202';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, { default => \@graphs, named => \@graphs } )>

Returns a new Dataset structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $dataset	= shift;
	return bless( [ 'DATASET', $pattern, $dataset ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern, $self->dataset);
}

=item C<< pattern >>

Returns the graph pattern of the named graph expression.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< dataset >>

Returns the dataset.

=cut

sub dataset {
	my $self	= shift;
	return $self->[2];
}

=item C<< defaults >>

Returns an array of the default graphs for the dataset.

=cut

sub defaults {
	my $self	= shift;
	my $dataset	= $self->dataset;
	return @{ $dataset->{default} || [] };
}

=item C<< named >>

Returns a HASH of the named graphs for the dataset.

=cut

sub named {
	my $self	= shift;
	my $dataset	= $self->dataset;
	return %{ $dataset->{named} || {} };
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '';
	die "sse not implemented for Dataset algebras";
	return sprintf(
		"(dataset\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->graph->sse( $context, "${prefix}${indent}" ),
		$self->pattern->sse( $context, "${prefix}${indent}" )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	die "as_sparql not implemented for Dataset algebras";
# 	my $string	= sprintf(
# 		"GRAPH %s %s",
# 		$self->graph->as_sparql( $context, $indent ),
# 		$self->pattern->as_sparql( $context, $indent ),
# 	);
# 	return $string;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	my $dataset	= $self->dataset;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		dataset		=> {
			default	=> [ map { $_->as_hash } $self->defaults ],
			named	=> [ map { $_->as_hash } $self->named ],
		},
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'DATASET';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return $self->pattern->referenced_variables;
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	return $self->pattern->binding_variables;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}


=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	my $dataset	= $self->dataset;
	my @default	= map { _qualify_node($_, $ns, $base) } @{ $dataset->{default} || [] };
	my @named	= map { _qualify_node($_, $ns, $base) } @{ $dataset->{named} || [] };
	my $pattern	= $self->pattern->qualify_uris( $ns, $base );
	return $class->new( $pattern, { default => \@default, named => \@named } );
}

sub _qualify_node {
	my $node	= shift;
	my $ns		= shift;
	my $base	= shift;
	if (blessed($node) and $node->isa('RDF::Query::Node::Resource')) {
		my $uri	= $node->uri;
		if (ref($uri)) {
			my ($n,$l)	= @$uri;
			unless (exists($ns->{ $n })) {
				throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
			}
			my $resolved	= join('', $ns->{ $n }, $l);
			$node			= RDF::Query::Node::Resource->new( $resolved, $base );
		}
	}
	return $node;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
