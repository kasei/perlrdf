# RDF::Query::Node
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Base class for RDF Nodes

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

our ($VERSION);
BEGIN {
	$VERSION	= '2.100';
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

Up-casts an RDF::Trine::Node object to an RDF::Query::Node object.

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
		return RDF::Query::Node::Variable->new( $n->blank_identifier );
	} else {
		die Dumper($n);
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
