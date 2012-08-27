package RDF::Trine::Store::API::TripleStore;
use Moose::Role;
with 'RDF::Trine::Store::API';

requires 'get_triples';

sub get_quads {}
sub count_quads {}
sub count_triples {}
sub size {}
sub get_graphs {}

1;
