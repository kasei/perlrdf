package RDF::Trine::Store::API::Writeable;
use Moose::Role;

requires 'add_statement';
requires 'remove_statement';

sub remove_statements {}
sub nuke {
	# override if your store leaves resources around that should be cleaned up
}

1;
