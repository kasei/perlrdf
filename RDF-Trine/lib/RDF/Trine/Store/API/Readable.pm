package RDF::Trine::Store::API::Readable;
use Moose::Role;

requires 'get_triples';
requires 'get_quads';
requires 'get_graphs';
requires 'count_triples';
requires 'count_quads';
requires 'size';

1;
