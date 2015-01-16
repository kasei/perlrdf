=head1 NAME

RDF::Trine::Store::DBI::SQLite - SQLite subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::SQLite version 1.012

=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::SQLite;
    my $store = RDF::Trine::Store->new({
                                         storetype => 'DBI',
                                         name      => 'test',
                                         dsn       => "dbi:SQLite:dbname=test.db",
                                         username  => '',
                                         password  => ''
                                       });


=head1 DESCRIPTION

=cut

package RDF::Trine::Store::DBI::SQLite;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store::DBI);


use Scalar::Util qw(blessed reftype refaddr);

our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}


sub _config_meta {
	return {
		required_keys	=> [qw(dsn username password name)],
		fields			=> {
			name		=> { description => 'Model Name', type => 'string' },
			dsn			=> { description => 'DSN', type => 'string', template => 'DBI:SQLite:dbname=[%filename%]' },
			filename	=> { description => 'SQLite Database Filename', type => 'filename' },
			username	=> { description => 'Username', type => 'string', value => '' },
			password	=> { description => 'Password', type => 'password', value => '' },
			driver		=> { description => 'Driver', type => 'string', value => 'SQLite' },
		},
	}
}

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store::DBI> class.

=over 4

=cut

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'DBI::SQLite';
	my $exists	= (-r $config->{filename});
	my $self	= $proto->SUPER::new_with_config( $config );
	unless ($exists) {
		$self->init();
	}
	return $self;
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	$self->SUPER::init();
	my $id		= RDF::Trine::Store::DBI::_mysql_hash( $name );
	
	my $table	= "Statements${id}";
	unless ($self->_table_exists($table)) {
		$dbh->begin_work;
		$dbh->do( "CREATE INDEX idx_${name}_spog ON Statements${id} (Subject,Predicate,Object,Context);" ) || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX idx_${name}_pogs ON Statements${id} (Predicate,Object,Context,Subject);" ) || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX idx_${name}_opcs ON Statements${id} (Object,Predicate,Context,Subject);" ) || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX idx_${name}_cpos ON Statements${id} (Context,Predicate,Object,Subject);" ) || do { $dbh->rollback; return };
		$dbh->commit;
	}
}


1; # Magic true value required at end of module
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
