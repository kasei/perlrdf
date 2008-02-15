# RDF::Base::Model
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Model - RDF model class.


=head1 VERSION

This document describes RDF::Base::Model version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Model;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Model;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
no warnings 'redefine';

use Moose;
use Moose::Util::TypeConstraints;

use Carp;

has 'storage'		=> ( is => 'rw', isa => 'RDF::Base::Storage', required => 1 );

# Module implementation here

=head1 METHODS

=over 4

=cut


=item C<< size >>

Returns the number of statements in the model.

=cut

sub size {
	my $self	= shift;
	return $self->storage->count_statements();
}

=item C<< add_statement ( $statement ) >>

=item C<< add_statement ( $subject, $predicate, $object ) >>

Adds the specified statement to the RDF graph.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub add_statement {
	my $self	= shift;
	$self->storage->add_statement( @_ );
}

=item C<< remove_statement ( $statement ) >>

=item C<< remove_statement ( $subject, $predicate, $object ) >>

Removes the specified statement from the RDF graph.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub remove_statement {
	my $self	= shift;
	$self->storage->remove_statement( @_ );
}

=item C<< exists_statement ( $statement ) >>

=item C<< exists_statement ( $subject, $predicate, $object ) >>

Returns true if the specified statement exists in the RDF graph.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub exists_statement {
	my $self	= shift;
	$self->storage->exists_statement( @_ );
}

=item C<< as_stream >>

Returns an iterator object of all statements in the RDF graph.

=cut

sub as_stream {
	my $self	= shift;
	return $self->storage->get_statements();
}

=item C<< get_statements ( $statement ) >>

=item C<< get_statements ( $subject, $predicate, $object ) >>

Returns an iterator object of all statements matching the specified statement.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be either undef (to match any node)
or RDF::Node objects.

=cut

sub get_statements {
	my $self	= shift;
	return $self->storage->get_statements( @_ );
}

=item C<< multi_get ( triples => \@triples, order => $order ) >>

XXX

=cut

sub multi_get {
	my $self	= shift;
	return $self->storage->multi_get( @_ );
}

=item C<< count_statements ( $statement ) >>

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns the number of statements in the model that match the specified $statement.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be either undef (to match any node)
or RDF::Node objects.

=cut

sub count_statements {
	my $self	= shift;
	return $self->storage->count_statements( @_ );
}

=item C<< supports ( $feature ) >>



=cut

sub supports {
	my $self	= shift;
	my $feature	= shift;
	
	my $storage	= $self->storage;
	my $package	= ref($storage);
#	warn "checking for feature $feature in $package";
	no strict 'refs';
	return ${ "${package}::supports" }{ $feature };
}


=item C<< storage >>

Returns the RDF::Base::Storage object being used as the triplestore.

=cut


=item C<< as_string >>

Returns a string representation of the statements in the model.

=cut

sub as_string {
	my $self	= shift;
	my $stream	= $self->as_stream;
	my $string	= "{\n";
	while (my $st = $stream->next) {
		$string	.= $st->as_string . "\n";
	}
	$string	.= "}\n";
	return $string;
}


1; # Magic true value required at end of module
__END__


=begin private

=item C<< meta >>

=end private

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
RDF::Base::Model requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


