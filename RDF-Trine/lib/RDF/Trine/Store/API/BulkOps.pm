package RDF::Trine::Store::API::BulkOps;
use Moose::Role;

requires 'begin_bulk_ops';
requires 'end_bulk_ops';

1;
