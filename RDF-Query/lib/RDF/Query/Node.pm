# RDF::Query::Node
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Base class for RDF Nodes

=head1 VERSION

This document describes RDF::Query::Node version 2.910.

=head1 METHODS

=over 4

=cut

package RDF::Query::Node;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed);

use RDF::Query::Node::Blank;
use RDF::Query::Node::Literal;
use RDF::Query::Node::Resource;
use RDF::Query::Node::Variable;

our ($VERSION, @ISA, @EXPORT_OK);
BEGIN {
	$VERSION	= '2.910';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(iri blank literal variable);
}

=item C<< is_variable >>

Returns true if this RDF node is a variable, false otherwise.

=cut

sub is_variable {
	my $self	= shift;
	return (blessed($self) and $self->isa('RDF::Query::Node::Variable'));
}

=item C<< compare ( $a, $b ) >>

Returns -1, 0, or 1 if $a is less than, equal to, or greater than $b, respectively,
according to the SPARQL sorting rules.

=cut

sub compare {
	my $a	= shift;
	my $b	= shift;
	warn 'compare';
	for ($a, $b) {
		unless ($_->isa('RDF::Query::Node')) {
			$_	= RDF::Query::Node->from_trine( $_ );
		}
	}
	
	local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
	return $a <=> $b;
}

=item C<< from_trine ( $node ) >>

Returns a new RDF::Query::Node object with the same value as $node, a
RDF::Trine::Node object. This essentially promotes C<< $node >> to a
node object with extra functionality provided by the RDF::Query package
(like SPARQL-defined ordering).

=cut

sub from_trine {
	my $class	= shift;
	my $n		= shift;
	if ($n->isa('RDF::Trine::Node::Variable')) {
		return RDF::Query::Node::Variable->new( $n->name );
	} elsif ($n->isa('RDF::Trine::Node::Literal')) {
		return RDF::Query::Node::Literal->new( $n->literal_value, $n->literal_value_language, $n->literal_datatype );
	} elsif ($n->isa('RDF::Trine::Node::Resource')) {
		return RDF::Query::Node::Resource->new( $n->uri_value );
	} elsif ($n->isa('RDF::Trine::Node::Blank')) {
		return RDF::Query::Node::Blank->new( $n->blank_identifier );
	} elsif ($n->isa('RDF::Trine::Node::Nil')) {
		return $n;
	} else {
		use Data::Dumper;
		Carp::confess "from_trine called with unrecognized node type:" . Dumper($n);
	}
}

=item C<< explain >>

Returns a string serialization of the node appropriate for display on the
command line. This method is primarily used by the C<< explain >> method of
the subclasses of RDF::Query::Plan.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $string	= "${indent}" . $self->as_sparql . "\n";
	return $string;
}

=back

=head1 FUNCTIONS

=over 4

=item C<< compare ( $node_a, $node_b ) >>

Returns -1, 0, or 1 if $node_a sorts less than, equal to, or greater than
$node_b in the defined SPARQL ordering, respectively. This function may be
used as the function argument to C<<sort>>.

=cut

sub compare {
	my $a	= shift;
	my $b	= shift;
	warn 'compare';
	for ($a, $b) {
		unless ($_->isa('RDF::Query::Node')) {
			$_	= RDF::Query::Node->from_trine( $_ );
		}
	}
	
	local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
	return $a <=> $b;
}


=item C<< iri ( $iri ) >>

Returns a RDF::Query::Node::Resource object with the given IRI value.

=cut

sub iri {
	my $iri	= shift;
	return RDF::Query::Node::Resource->new( $iri );
}

=item C<< blank ( $id ) >>

Returns a RDF::Query::Node::Blank object with the given identifier.

=cut

sub blank {
	my $id	= shift;
	return RDF::Query::Node::Blank->new( $id );
}

=item C<< literal ( $value, $lang, $dt ) >>

Returns a RDF::Query::Node::Literal object with the given value and optional
language/datatype.

=cut

sub literal {
	return RDF::Query::Node::Literal->new( @_ );
}

=item C<< variable ( $name ) >>

Returns a RDF::Query::Node::Variable object with the given variable name.

=cut

sub variable {
	my $name	= shift;
	return RDF::Query::Node::Variable->new( $name );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
