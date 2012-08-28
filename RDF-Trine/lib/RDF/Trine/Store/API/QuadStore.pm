package RDF::Trine::Store::API::QuadStore;
use Moose::Role;
use Scalar::Util qw(blessed);

with 'RDF::Trine::Store::API';

requires 'get_quads';
requires 'get_graphs';

=item C<< get_triples ( $subject, $predicate, $object ) >>

Returns a iterator object of all triples matching the specified subject,
predicate, object. Any of the arguments may be undef to match any value.

=cut

sub get_triples {
	my $self	= shift;
	my @nodes	= @_[0..2];
	my $iter	= $self->get_quads( @nodes );
	my %seen;
	return RDF::Trine::Iterator->new(sub{
		while (1) {
			my $q	= $iter->next;
			return unless $q;
			
			my @nodes	= $q->nodes;
			my $t		= RDF::Trine::Statement::Triple->new( @nodes[0..2] );
			next if ($seen{ $t->as_string }++);
			return $t;
		}
	});
}

=item C<< count_quads ( $subject, $predicate, $object, $graph ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and graphs. Any of the arguments may be undef to match any
value.

=cut

sub count_quads {
	my $self	= shift;
	my $iter	= $self->get_quads( @_ );
	my $count	= 0;
	while (my $t = $iter->next) {
		$count++;
	}
	return $count;
}

=item C<< count_triples ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_triples {
	my $self	= shift;
	my @nodes	= @_;
	my $count	= 0;
	my $iter	= $self->get_triples( @nodes );
	while (my $st = $iter->next) {
		$count++;
	}
	return $count;
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->count_quads();
}

1;
