# RDF::Trine::Model::Union
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model::Union - Union models for joining multiple stores together

=head1 VERSION

This document describes RDF::Trine::Model::Union version 1.012

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Model> class.

=over 4

=cut

package RDF::Trine::Model::Union;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Model);
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Store;

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

################################################################################

=item C<< new ( @stores ) >>

Returns a new union-model over the list of supplied rdf stores.

=cut

sub new {
	my $class	= shift;
	my @stores	= @_;
	my $self	= bless({ stores => \@stores }, $class);
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the first rdf store.

=cut

sub add_statement {
	my $self	= shift;
	my @iterators;
	my ($store)	= $self->_stores;
	$store->add_statement( @_ );
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from all of the rdf stores.

=cut

sub remove_statement {
	my $self	= shift;
	foreach my $store ($self->_stores) {
		$store->remove_statement( @_ );
	}
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes all statements matching the supplied C<$statement> pattern from all of the rdf stores.

=cut

sub remove_statements {
	my $self	= shift;
	foreach my $store ($self->_stores) {
		$store->remove_statements( @_ );
	}
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my $count	= 0;
	foreach my $store ($self->_stores) {
		$count	+= $store->count_statements( @_ );
	}
	return $count;
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects from all of the rdf stores. Any of the arguments may be
undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @iterators;
	foreach my $store ($self->_stores) {
		my $i	= $store->get_statements( @_ );
		push(@iterators, $i);
# 		my @data;
# 		while (my $d = $i->next) {
# 			warn '++++++++++++++++++ ' . $d->as_string;
# 			
# 		}
# 		
# 		my $m	= $i->materialize;
# 		push(@iterators, $m);
	}
	while (@iterators > 1) {
		my $i	= shift(@iterators);
		my $j	= shift(@iterators);
		unshift(@iterators, $i->concat( $j ));
	}
	return $iterators[0]->unique;
}

# =item C<< get_pattern ( $bgp [, $context] ) >>
# 
# Returns a stream object of all bindings matching the specified graph pattern.
# 
# =cut
# 
# sub get_pattern {
# 	my $self	= shift;
# 	my @iterators;
# 	foreach my $store ($self->_stores) {
# 		push(@iterators, $store->get_pattern( @_ ));
# 	}
# 	while (@iterators > 1) {
# 		my $i	= shift(@iterators);
# 		my $j	= shift(@iterators);
# 		unshift(@iterators, $i->concat( $j ));
# 	}
# 	return $iterators[0];
# }

sub _stores {
	my $self	= shift;
	return @{ $self->{stores} };
}

sub _store {
	my $self	= shift;
	return;
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
