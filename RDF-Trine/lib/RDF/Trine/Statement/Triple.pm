package RDF::Trine::Statement::Triple;

use Moose;
use namespace::autoclean;

with qw(
	RDF::Trine::Statement::API
);

sub isa {
	my ($self, $isa) = @_;
	if ($isa eq 'RDF::Trine::Statement')
	{
		Carp::carp("isa(RDF::Trine::Statement) is deprecated; use DOES(RDF::Trine::Statement::API)");
		return 1;
	}
	$self->SUPER::isa($isa);
}

sub type { 'TRIPLE' }
sub node_names { qw(subject predicate object) }

sub to_triple { +shift }  # return $self

sub as_ntriples {
	my $self = shift;
	join q[ ] => (
		(map { $_->as_ntriples } $self->nodes),
		".\n"
	);
}

sub from_sse {
	my $class   = shift;
	my $context = $_[1];
	$_			= $_[0];
	if (m/^[(]triple/) {
		s/^[(]triple\s+//;
		my @nodes;
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		if (m/^\s*[)]/) {
			s/^\s*[)]//;
			return RDF::Trine::Statement::Triple->new( @nodes );
		} else {
			throw RDF::Trine::Error -text => "Cannot parse end-of-triple from SSE string: >>$_<<";
		}
	} else {
		throw RDF::Trine::Error -text => "Cannot parse triple from SSE string: >>$_<<";
	}
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

RDF::Trine::Statement::Triple - an RDF statement with no graph URI

=head1 DESCRIPTION

=head2 Constructor

=over

=item C<< new($s, $p, $o) >>

=item C<< new({ subject => $s, predicate => $p, object => $o }) >>

Constructs a triple statement.

=item C<< from_sse($string) >>

Alternative constructor.

=back

=head2 Attributes

=over

=item C<< subject >>

A node representing the subject of the statement.

=item C<< predicate >>

A node representing the predicate of the statement.

=item C<< object >>

A node representing the object of the statement.

=back

=head2 Methods

This class provides the following methods:

=over

=item C<< type >>

Returns the string "TRIPLE".

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor, will produce a clone of this algebra pattern.

=item C<< clone >>

Returns a clone of this argument.

=item C<< nodes >>

Returns the subject, predicate and object nodes as a list.

=item C<< node_names >>

Returns "subject", "predicate" and "object" strings as a list.

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

Returns C<< $self >>. This is provided to ease polymorphism with
L<RDF::Trine::Statement::Quad>.

=item C<< rdf_compatible >>

Returns true if and only if the statement can be expressed in RDF. That is,
the subject of the statement must be a resource or blank node; the predicate
must be a resource; and the object must be a resource, blank node or literal.

RDF::Trine::Statement::Triple does allow statements to be created which cannot
be expressed in RDF - for instance, statements including variables.

=item C<< as_ntriples >>

Returns the statement as an NTriples string.

=back


