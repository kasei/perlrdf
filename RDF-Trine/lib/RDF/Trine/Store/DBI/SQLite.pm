=head1 NAME

RDF::Trine::Store::DBI::SQLite - SQLite subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::SQLite version 0.124_04

=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::SQLite;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
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

package RDF::Trine::Store::DBI::SQLite;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store::DBI);

use Scalar::Util qw(blessed reftype refaddr);

our $VERSION	= "0.124_04";



=head1 METHODS

=over 4

=cut

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	$self->SUPER::init();
	my $id		= RDF::Trine::Store::DBI::_mysql_hash( $name );
	
	$dbh->begin_work;
	$dbh->do( "CREATE INDEX idx_${name}_spog ON Statements${id} (Subject,Predicate,Object,Context);" ) || do { $dbh->rollback; return undef };
	$dbh->do( "CREATE INDEX idx_${name}_pogs ON Statements${id} (Predicate,Object,Context,Subject);" ) || do { $dbh->rollback; return undef };
	$dbh->do( "CREATE INDEX idx_${name}_opcs ON Statements${id} (Object,Predicate,Context,Subject);" ) || do { $dbh->rollback; return undef };
	$dbh->do( "CREATE INDEX idx_${name}_cpos ON Statements${id} (Context,Predicate,Object,Subject);" ) || do { $dbh->rollback; return undef };
	$dbh->commit;
}


1; # Magic true value required at end of module
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-rdf-store-dbi@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
