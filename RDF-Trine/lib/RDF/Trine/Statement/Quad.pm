package RDF::Trine::Statement::Quad;

use Moose;
use MooseX::Aliases;
use namespace::autoclean;

with qw(
	RDF::Trine::Statement::API
	RDF::Trine::Statement::API::Element::Graph
);

alias context => 'graph';

sub isa {
	my ($self, $isa) = @_;
	if ($isa eq 'RDF::Trine::Statement')
	{
		Carp::carp("isa(RDF::Trine::Statement) is deprecated; use DOES(RDF::Trine::Statement::API)");
		return 1;
	}
	$self->SUPER::isa($isa);
}

sub type { 'QUAD' }
sub node_names { qw(subject predicate object graph) }

sub from_sse {
	my $class   = shift;
	my $context = $_[1];
	$_          = $_[0];
	if (m/^[(]quad/) {
		s/^[(]quad\s+//;
		my @nodes;
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		if (m/^\s*[)]/) {
			s/^\s*[)]//;
			return RDF::Trine::Statement->new( @nodes );
		} else {
			throw RDF::Trine::Error -text => "Cannot parse end-of-quad from SSE string: >>$_<<";
		}
	} else {
		throw RDF::Trine::Error -text => "Cannot parse quad from SSE string: >>$_<<";
	}
}

sub as_nquads {
	my $self = shift;
	join q[ ] => (
		(map { $_->as_ntriples } $self->nodes),
		".\n"
	);
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

RDF::Trine::Statement::Quad - an RDF statement plus a graph URI

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new($s, $p, $o, $g) >>

=item C<< new({ subject => $s, predicate => $p, object => $o, graph => $g }) >>

Constructs a quad statement.

=item C<< from_sse($string) >>

Alternative constructor.

=item C<< from_redland($redland_st, $graph) >>

Consumes triples from RDF::Redland.

=back

=head2 Attributes

=over

=item C<< subject >>

A node representing the subject of the statement.

=item C<< predicate >>

A node representing the predicate of the statement.

=item C<< object >>

A node representing the object of the statement.

=item C<< graph >>

A node representing the graph of the statement. (This is not restricted
to L<RDF::Trine::Node::Resource>.)

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< type >>

Returns the string "QUAD".

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor, will produce a clone of this algebra pattern.

=item C<< clone >>

Returns a clone of this argument.

=item C<< nodes >>

Returns the subject, predicate, object and graph nodes as a list.

=item C<< node_names >>

Returns "subject", "predicate", "object" and "graph" strings as a list.

=item C<< as_string >>

Returns this statement as a string. (Currently in SSE syntax.)

=item C<< sse >>

Returns this statement as an SSE string.

=item C<< has_blanks >>

Returns true if the statement contains any blank nodes. (In fact, returns
the number of such nodes in scalar context, and a list of those nodes in
list context.)

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=item C<< bind_variables(\%bound) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=item C<< subsumes($other) >>

Returns true if this statement will subsume the C<< $other >> statement when matched against a triple store.

=item C<< to_triple >>

Returns an L<RDF::Trine::Statement::Triple> with the same subject, predicate
and object as this statement, but no graph.

=item C<< rdf_compatible >>

Returns true if and only if the statement can be expressed in RDF. That is,
the subject of the statement must be a resource or blank node; the predicate
must be a resource; and the object must be a resource, blank node or literal.

The graph is completely ignored.

RDF::Trine::Statement::Triple does allow statements to be created which cannot
be expressed in RDF - for instance, statements including variables.

=item C<< as_ntriples >>

Returns the statement as an NTriples string, ignoring the graph.

=item C<< as_nquads >>

Returns the statement as an NQuads string.

=back


