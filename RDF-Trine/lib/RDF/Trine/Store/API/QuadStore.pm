package RDF::Trine::Store::API::QuadStore;
use Moose::Role;
with 'RDF::Trine::Store::API';

requires 'get_quads';
requires 'get_graphs';

sub get_triples {}
sub count_quads {
	die "foo";
}
sub count_triples {}
sub size {
	my $self	= shift;
	return $self->count_quads( undef, undef, undef, undef );
}

1;
