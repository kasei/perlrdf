# RDF::Query::Algebra::Triple
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Triple - Algebra class for Triple patterns

=cut

package RDF::Query::Algebra::Triple;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra RDF::Trine::Statement);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %AS_SPARQL;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.100';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $s, $p, $o )>

Returns a new Triple structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	foreach my $i (0 .. 2) {
		unless (defined($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Query::Node::Variable->new($node_methods[ $i ]);
		}
	}
	return $class->SUPER::new( @nodes );
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	if (exists $AS_SPARQL{ refaddr( $self ) }) {
		return $AS_SPARQL{ refaddr( $self ) };
	} else {
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
		$AS_SPARQL{ refaddr( $self ) }	= $string;
		return $string;
	}
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

=item C<< subsumes ( $pattern ) >>

Returns true if the triple subsumes the pattern, false otherwise.

=cut

sub subsumes {
	my $self	= shift;
	my $pattern	= shift;
	return 0 unless ($pattern->isa('RDF::Trine::Statement'));
	foreach my $method (@node_methods) {
		my $snode	= $self->$method();
		next if ($snode->isa('RDF::Trine::Node::Variable'));
		my $pnode	= $pattern->$method();
		next if ($snode->equal( $pnode ));
		return 0;
	}
	return 1;
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

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		my @nodes	= $self->nodes;
		@nodes	= map { $bridge->as_native( $_, $base, $ns ) } @nodes;
		my $fixed	= $class->new( @nodes );
		return $fixed;
	}
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

sub _from_sse {
	my $class	= shift;
	return RDF::Trine::Statement->from_sse( @_ );
}

sub DESTROY {
	my $self	= shift;
	delete $AS_SPARQL{ refaddr( $self ) };
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
