=head1 NAME

RDF::Trine::Store::DBI::SQLite - SQLite subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::SQLite version 1.015

=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::SQLite;
    my $store = RDF::Trine::Store->new({
                                         storetype => 'DBI',
                                         name      => 'test',
                                         dsn       => "dbi:SQLite:dbname=test.db",
                                         username  => '',
                                         password  => ''
                                       });


=head1 CHANGES IN VERSION 1.015

The schema used to encode RDF data in SQLite changed in RDF::Trine version
1.015 to fix a bug that was causing data loss. This change is not backwards
compatible, and is not compatible with the shared schema used by the other
database backends supported by RDF::Trine (PostgreSQL and MySQL).

To exchange data between SQLite and other databases, the data will require
export to an RDF serialization and re-import to the new database.

=cut

package RDF::Trine::Store::DBI::SQLite;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store::DBI);


use Scalar::Util qw(blessed reftype refaddr);
use Encode;
use Digest::MD5 ('md5');
use Math::BigInt;

our $VERSION;
BEGIN {
	$VERSION	= "1.015";
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

# SQLite only supports 64-bit SIGNED integers, so this hash function masks out
# the high-bit on hash values (unlike the superclass which produces full 64-bit
# integers)
sub _mysql_hash {
	if (ref($_[0])) {
		my $self = shift;
	}
	Carp::confess unless scalar(@_);
	my $data	= encode('utf8', shift);
	my @data	= unpack('C*', md5( $data ));
	my $sum		= Math::BigInt->new('0');
	# CHANGE: 7 -> 6, Smaller numbers for Sqlite which does not support real 64-bit :(
	foreach my $count (0 .. 7) {
		my $data	= Math::BigInt->new( $data[ $count ] ); #shift(@data);
		my $part	= $data << (8 * $count);
#		warn "+ $part\n";
		$sum		+= $part;
	}
#	warn "= $sum\n";
	$sum    = $sum->band(Math::BigInt->new('0x7fff_ffff_ffff_ffff'));
	$sum	=~ s/\D//;	# get rid of the extraneous '+' that pops up under perl 5.6
	return $sum;
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	$self->SUPER::init();
	my $id		= $self->_mysql_hash( $name );
	
	my $table	= "Statements${id}";
	local($dbh->{AutoCommit})	= 0;
	unless ($self->_table_exists($table)) {
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
