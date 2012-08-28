package RDF::Trine::Store::API::Writeable;
use Moose::Role;

requires 'add_statement';
requires 'remove_statement';

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements { # Fallback implementation
  my $self = shift;
  my $iterator = $self->get_statements(@_);
  while (my $st = $iterator->next) {
    $self->remove_statement($st);
  }
}

sub nuke {
	# override if your store leaves resources around that should be cleaned up
}

1;
