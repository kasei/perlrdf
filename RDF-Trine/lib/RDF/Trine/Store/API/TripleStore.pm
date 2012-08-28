package RDF::Trine::Store::API::TripleStore;
use Moose::Role;
use Scalar::Util qw(blessed);

with 'RDF::Trine::Store::API';

requires 'get_triples';


=item C<< get_quads ( $subject, $predicate, $object, $graph ) >>

Returns a iterator object of all quads matching the specified subject,
predicate, object. Any of the arguments may be undef to match any value.
For all stores implementing this (triplestore) role, the iterator will be empty
unless C<< $graph >> is undefined or is an RDF::Trine::Node::Nil object.
If C<< $graph >> is undefined, all quads returned by the iterator will have
a graph value which is a RDF::Trine::Node::Nil object.

=cut

sub get_quads {
	my $self	= shift;
	my @nodes	= @_[0..3];
	if (not(defined($nodes[3])) or (blessed($nodes[3])) and $nodes[3]->isa('RDF::Trine::Node::Nil')) {
		my $iter	= $self->get_triples(@nodes[0..2]);
		my $graph	= RDF::Trine::Node::Nil->new();
		return RDF::Trine::Iterator->new(sub{
			my $t	= $iter->next;
			return unless $t;
			my $quad	= RDF::Trine::Statement::Quad->new( $t->nodes, $graph );
			return $quad;
		});
	} else {
		return RDF::Trine::Iterator->new([]);
	}
}

=item C<< count_quads ( $subject, $predicate, $object, $graph ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and graphs. Any of the arguments may be undef to match any
value. For all stores implementing this (triplestore) role, the count will be
zero unless C<< $graph >> is undefined or is an RDF::Trine::Node::Nil object.

=cut

sub count_quads {
	my $self	= shift;
	my @nodes	= @_[0..3];
	if (not(defined($nodes[3])) or (blessed($nodes[3])) and $nodes[3]->isa('RDF::Trine::Node::Nil')) {
		return $self->count_triples(@_);
	} else {
		return 0;
	}
}

=item C<< count_triples ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_triples {
	my $self	= shift;
	my $iter	= $self->get_triples( @_ );
	my $count	= 0;
	while (my $t = $iter->next) {
		$count++;
	}
	return $count;
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->count_triples();
}

=item C<< get_graphs >>

Returns an RDF::Trine::Iterator containing the implicit graph node for all
triples in the triplestore (an instance of RDF::Trine::Node::Nil).

=cut

sub get_graphs {
	my $self	= shift;
	my $graph	= RDF::Trine::Node::Nil->new();
 	return RDF::Trine::Iterator->new( [$graph] );
}
*get_contexts = \&get_graphs;

1;
