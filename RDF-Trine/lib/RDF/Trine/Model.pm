# RDF::Trine::Model
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model - Model class

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model;

use strict;
use warnings;
no warnings 'redefine';

our ($debug, $VERSION);
BEGIN {
	$debug		= 0;
	$VERSION	= '0.107';
}

use Scalar::Util qw(blessed);
use RDF::Trine::Node;
use RDF::Trine::Store::DBI;

=item C<< new ( @stores ) >>

Returns a new model over the supplied rdf store.

=cut

sub new {
	my $class	= shift;
	my $store	= shift;
	my $self	= bless({ store => $store }, $class);
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the rdf store.

=cut

sub add_statement {
	my $self	= shift;
	return $self->_store->add_statement( @_ );
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the rdf store.

=cut

sub remove_statement {
	my $self	= shift;
	return $self->_store->remove_statement( @_ );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes all statements matching the supplied C<$statement> pattern from the rdf store.

=cut

sub remove_statements {
	my $self	= shift;
	return $self->_store->remove_statements( @_ );
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	return $self->_store->count_statements( @_ );
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects from the rdf store. Any of the arguments may be undef to
match any value.

=cut

sub get_statements {
	my $self	= shift;
	return $self->_store->get_statements( @_ );
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my (@triples)	= ($bgp->isa('RDF::Trine::Statement')) ? $bgp : $bgp->triples;
	unless (@triples) {
		throw RDF::Trine::Error::CompilationError -text => 'Cannot call get_pattern() with empty pattern';
	}
	return $self->_store->get_pattern( $bgp, @_ );
}

=item C<< get_contexts >>

=cut

sub get_contexts {
	my $self	= shift;
	my $store	= $self->_store;
	return $store->get_contexts( @_ );
}

=item C<< as_stream >>

Returns an iterator object containing every statement in the model.

=cut

sub as_stream {
	my $self	= shift;
	my $stream	= $self->get_statements( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	return $stream;
}

sub _store {
	my $self	= shift;
	return $self->{store};
}

sub _debug {
	my $self	= shift;
	my $stream	= $self->as_stream;
	while (my $s = $stream->next) {
		warn '[DEBUG] ' . $s->as_string . "\n";
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
