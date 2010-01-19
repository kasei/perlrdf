=head1 NAME

RDF::Trine::Store::B - RDF store using the Lib B backend library


=head1 VERSION

This document describes RDF::Trine::Store::B version 0.109


=head1 SYNOPSIS

    use RDF::Trine::Store::B;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.

=cut

use strict;
use warnings;
no warnings 'redefine';
use XSLoader;

our $VERSION	= 0.109;
XSLoader::load "RDF::Trine::Store::B", $VERSION;

use RDF::Trine::Error;


=head1 METHODS

=over 4

=item C<new ( $filename_prefix )>

Returns a new storage object using the supplied arguments to construct a DBI
object for the underlying database.

=cut





=item C<< temporary_store >>

=cut

sub temporary_store {
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
}

=item C<< get_contexts >>

=cut

sub get_contexts {
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
}
