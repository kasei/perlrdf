# RDF::Query::Algebra::Quad
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Quad - Algebra class for Quad patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Quad version 2.910.

=cut

package RDF::Query::Algebra::Quad;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra RDF::Trine::Statement::Quad);

use Data::Dumper;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

my %QUAD_LABELS;
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

=item C<new ( $s, $p, $o, $g )>

Returns a new Quad structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	unless (scalar(@nodes) == 4) {
		throw RDF::Query::Error::MethodInvocationError -text => "Quad constructor must have four node arguments";
	}
	my @names	= qw(subject predicate object context);
	foreach my $i (0 .. 3) {
		unless (defined($nodes[ $i ]) and blessed($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Query::Node::Variable->new($names[ $i ]);
		}
		unless ($nodes[ $i ]->isa('RDF::Query::Node')) {
			$nodes[ $i ]	= RDF::Query::Node->from_trine( $nodes[ $i ] );
		}
	}
	
	return $class->SUPER::new( @nodes );
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	
	my $pred	= $self->predicate;
	if ($pred->isa('RDF::Trine::Node::Resource') and $pred->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		$pred	= 'a';
	} else {
		$pred	= $pred->as_sparql( $context );
	}
	
	my $string	= sprintf(
		"%s %s %s .",
		$self->subject->as_sparql( $context ),
		$pred,
		$self->object->as_sparql( $context ),
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
		nodes		=> [ map { $_->as_hash } $self->nodes ],
	};
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @nodes	= $self->nodes;
	my @blanks	= grep { $_->isa('RDF::Trine::Node::Blank') } @nodes;
	return map { $_->blank_identifier } @blanks;
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
	my @nodes;
	foreach my $n ($self->nodes) {
		my $blessed	= blessed($n);
		if ($blessed and $n->isa('RDF::Query::Node::Resource')) {
			my $uri	= $n->uri;
			if (ref($uri)) {
				my ($n,$l)	= @$uri;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base_uri );
				push(@nodes, $resolved);
			} else {
				push(@nodes, $n);
			}
		} elsif ($blessed and $n->isa('RDF::Query::Node::Literal')) {
			my $node	= $n;
			my $dt	= $node->literal_datatype;
			if (ref($dt)) {
				my ($n,$l)	= @$dt;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base_uri );
				my $lit			= RDF::Query::Node::Literal->new( $node->literal_value, undef, $resolved->uri_value );
				push(@nodes, $lit);
			} else {
				push(@nodes, $node);
			}
		} else {
			push(@nodes, $n);
		}
	}
	return $class->new( @nodes );
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $bf		= '';
	foreach my $n ($self->nodes) {
		$bf		.= ($n->isa('RDF::Query::Node::Variable'))
				? 'f'
				: 'b';
	}
	return $bf;
}

=item C<< distinguish_bnode_variables >>

Returns a new Quad object with blank nodes replaced by distinguished variables.

=cut

sub distinguish_bnode_variables {
	my $self	= shift;
	my $class	= ref($self);
	my @nodes	= $self->nodes;
	foreach my $i (0 .. $#nodes) {
		if ($nodes[$i]->isa('RDF::Query::Node::Blank')) {
			$nodes[$i]	= $nodes[$i]->make_distinguished_variable;
		}
	}
	return $class->new( @nodes );
}

=item C<< label ( $label => $value ) >>

Sets the named C<< $label >> to C<< $value >> for this quad object.
If no C<< $value >> is given, returns the current label value, or undef if none
exists.

=cut

sub label {
	my $self	= shift;
	my $addr	= refaddr($self);
	my $label	= shift;
	if (@_) {
		my $value	= shift;
		$QUAD_LABELS{ $addr }{ $label }	= $value;
	}
	if (exists $QUAD_LABELS{ $addr }) {
		return $QUAD_LABELS{ $addr }{ $label };
	} else {
		return;
	}
}

sub DESTROY {
	my $self	= shift;
	my $addr	= refaddr( $self );
	delete $QUAD_LABELS{ $addr };
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
