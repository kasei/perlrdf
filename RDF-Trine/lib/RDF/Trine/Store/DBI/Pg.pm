=head1 NAME

RDF::Trine::Store::DBI::Pg - PostgreSQL subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::Pg version 1.012

=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::Pg;

=head1 DESCRIPTION

=cut

package RDF::Trine::Store::DBI::Pg;

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
			dsn			=> { description => 'DSN', type => 'string', template => 'DBI:Pg:dbname=[%database%]' },
			database	=> { description => 'Database Name', type => 'string' },
			username	=> { description => 'Username', type => 'string' },
			password	=> { description => 'Password', type => 'password' },
			driver		=> { description => 'Driver', type => 'string', value => 'Pg' },
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
	$config->{storetype}	= 'DBI::Pg';
	return $proto->SUPER::new_with_config( $config );
}

sub _column_name {
	my $self	= shift;
	my @args	= @_;
	my $col		= lc(join('_', @args));
	return $col;
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	my $id		= RDF::Trine::Store::DBI::_mysql_hash( $name );
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	unless ($self->_table_exists("literals")) {
		$dbh->begin_work;
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE literals (
				ID NUMERIC(20) PRIMARY KEY,
				Value text NOT NULL,
				Language text NOT NULL DEFAULT '',
				Datatype text NOT NULL DEFAULT ''
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE resources (
				ID NUMERIC(20) PRIMARY KEY,
				URI text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE bnodes (
				ID NUMERIC(20) PRIMARY KEY,
				Name text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE models (
				ID NUMERIC(20) PRIMARY KEY,
				Name text NOT NULL
			);
END
		
		$dbh->commit or warn $dbh->errstr;
	}
	
	unless ($self->_table_exists("statements${id}")) {
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); return };
			CREATE TABLE statements${id} (
				Subject NUMERIC(20) NOT NULL,
				Predicate NUMERIC(20) NOT NULL,
				Object NUMERIC(20) NOT NULL,
				Context NUMERIC(20) NOT NULL DEFAULT 0,
				PRIMARY KEY (Subject, Predicate, Object, Context)
			);
END
# 		$dbh->do( "DELETE FROM Models WHERE ID = ${id}") || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
		$dbh->do( "INSERT INTO Models (ID, Name) VALUES (${id}, ?)", undef, $name );
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
