# RDF::Query::Algebra::Triple
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Triple - Algebra class for Triple patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Triple version 2.910.

=cut

package RDF::Query::Algebra::Triple;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra RDF::Trine::Statement);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %TRIPLE_LABELS;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

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
		if (blessed($nodes[ $i ]) and not($nodes[ $i ]->isa('RDF::Query::Node'))) {
			$nodes[ $i ]	= RDF::Query::Node->from_trine( $nodes[ $i ] );
		}
	}
	return $class->_new( @nodes );
}

sub _new {
	my $class	= shift;
	return $class->SUPER::new( @_ );
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $pred	= $self->predicate;
	if ($pred->isa('RDF::Trine::Node::Resource') and $pred->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		$pred	= 'a';
	} else {
		$pred	= $pred->as_sparql( $context );
	}
	
	my $subj	= $self->subject->as_sparql( $context );
	my $obj		= $self->object->as_sparql( $context );
	my $string	= sprintf(
		"%s %s %s .",
		$subj,
		$pred,
		$obj,
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
		type 	=> lc($self->type),
		nodes	=> [ map { $_->as_hash } $self->nodes ],
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
	my $t		= RDF::Query::Node::Blank->new();
	my @nodes	= $self->nodes;
	foreach (@nodes) {
		if (blessed($_) and $_->isa('RDF::Trine::Node::Variable')) {
			$_	= RDF::Query::Node::Blank->new( "variable_" . $_->name );
		}
	}
	
	$model->add_statement( RDF::Trine::Statement->new($t, $spin->subject, $nodes[0]) );
	$model->add_statement( RDF::Trine::Statement->new($t, $spin->predicate, $nodes[1]) );
	$model->add_statement( RDF::Trine::Statement->new($t, $spin->object, $nodes[2]) );
	return $t;
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @nodes	= $self->nodes;
	my @blanks	= grep { Carp::confess Dumper($_) unless blessed($_); $_->isa('RDF::Trine::Node::Blank') } @nodes;
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

=item C<< label ( $label => $value ) >>

Sets the named C<< $label >> to C<< $value >> for this triple object.
If no C<< $value >> is given, returns the current label value, or undef if none
exists.

=cut

sub label {
	my $self	= shift;
	my $addr	= refaddr($self);
	my $label	= shift;
	if (@_) {
		my $value	= shift;
		$TRIPLE_LABELS{ $addr }{ $label }	= $value;
	}
	if (exists $TRIPLE_LABELS{ $addr }) {
		return $TRIPLE_LABELS{ $addr }{ $label };
	} else {
		return;
	}
}

sub DESTROY {
	my $self	= shift;
	my $addr	= refaddr( $self );
	delete $TRIPLE_LABELS{ $addr };
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
