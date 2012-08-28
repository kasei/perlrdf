package RDF::Trine::Store::API::Readable;
use Moose::Role;

requires 'get_triples';
requires 'get_quads';
requires 'get_graphs';
requires 'count_triples';
requires 'count_quads';
requires 'size';

=item C<< get_statements ( $subject, $predicate, $object [, $graph] ) >>

Returns an iterator of all statements matching the specified subject,
predicate, object, and graphs. Any of the arguments may be undef to match
any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	if (scalar(@_) >= 4) {
		return $self->get_quads( @nodes );
	} else {
		return $self->get_triples( @nodes[0..2] );
	}
}

=item C<< count_statements ( $subject, $predicate, $object [, $graph] ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and graph. Any of the arguments may be undef to match
any value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	if (scalar(@_) >= 4) {
		return $self->count_quads( @nodes );
	} else {
		return $self->count_triples( @nodes[0..2] );
	}
}


1;
