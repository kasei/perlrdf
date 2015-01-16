=head1 NAME

RDF::Trine::Store::DBI::mysql - Mysql subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::mysql version 1.012

=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::mysql;

=head1 DESCRIPTION

=cut

package RDF::Trine::Store::DBI::mysql;

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
			dsn			=> { description => 'DSN', type => 'string', template => 'DBI:mysql:database=[%database%]' },
			database	=> { description => 'Database Name', type => 'string' },
			username	=> { description => 'Username', type => 'string' },
			password	=> { description => 'Password', type => 'password' },
			driver		=> { description => 'Driver', type => 'string', value => 'mysql' },
		},
	}
}

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store::DBI> class.

=over 4

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'DBI::mysql';
	return $proto->SUPER::new_with_config( $config );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $context	= shift;

	my $dbh		= $self->dbh;
# 	Carp::confess unless (blessed($stmt));
	my $stable	= $self->statements_table;
	unless (blessed($stmt) and $stmt->can('nodes')) {
		Carp::confess "No statement passed to add_statement";
	}
	my @nodes	= $stmt->nodes;
	foreach my $n (@nodes) {
		$self->_add_node( $n );
	}
	
	my @values	= map { $self->_mysql_node_hash( $_ ) } @nodes;
	if ($stmt->isa('RDF::Trine::Statement::Quad')) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
		}
		$context	= $stmt->context;
	} else {
		my $cid		= do {
			if ($context) {
				$self->_add_node( $context );
				$self->_mysql_node_hash( $context );
			} else {
				0
			}
		};
		push(@values, $cid);
	}
	my $sql		= sprintf( "INSERT IGNORE INTO ${stable} (Subject, Predicate, Object, Context) VALUES (?,?,?,?)" );
	my $sth		= $dbh->prepare( $sql );
	$sth->execute(@values);
}

sub _add_node {
	my $self	= shift;
	my $node	= shift;
	my $hash	= $self->_mysql_node_hash( $node );
	my $dbh		= $self->dbh;
	
	my @cols;
	my $table;
	my %values;
# 	Carp::confess unless (blessed($node));
	if ($node->is_blank) {
		$table	= "Bnodes";
		@cols	= qw(ID Name);
		@values{ @cols }	= ($hash, $node->blank_identifier);
	} elsif ($node->is_resource) {
		$table	= "Resources";
		@cols	= qw(ID URI);
		@values{ @cols }	= ($hash, $node->uri_value);
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		$table	= "Literals";
		@cols	= qw(ID Value);
		@values{ @cols }	= ($hash, $node->literal_value);
		$values{ 'Datatype' }	= '';
		$values{ 'Language' }	= '';
		if ($node->has_language) {
			push(@cols, 'Language');
			$values{ 'Language' }	= $node->literal_value_language;
		} elsif ($node->has_datatype) {
			push(@cols, 'Datatype');
			$values{ 'Datatype' }	= $node->literal_datatype;
		}
	}
	
	my $sql	= "INSERT IGNORE INTO ${table} (" . join(', ', @cols) . ") VALUES (" . join(',',('?')x scalar(@cols)) . ")";
	my $sth	= $dbh->prepare( $sql );
	$sth->execute( map "$_", @values{ @cols } );
	return $hash;
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	my $id		= RDF::Trine::Store::DBI::_mysql_hash( $name );
	local($dbh->{AutoCommit})	= 0;
	unless ($self->_table_exists("Literals")) {
		$dbh->begin_work;
		$dbh->do( <<"END" ) || do { $dbh->rollback; return };
			CREATE TABLE IF NOT EXISTS Literals (
				ID bigint unsigned PRIMARY KEY,
				Value longtext NOT NULL,
				Language text NOT NULL,
				Datatype text NOT NULL
			) CHARACTER SET utf8 COLLATE utf8_bin;
END

		$dbh->do( <<"END" ) || do { $dbh->rollback; return };
			CREATE TABLE IF NOT EXISTS Resources (
				ID bigint unsigned PRIMARY KEY,
				URI text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $dbh->rollback; return };
			CREATE TABLE IF NOT EXISTS Bnodes (
				ID bigint unsigned PRIMARY KEY,
				Name text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $dbh->rollback; return };
			CREATE TABLE IF NOT EXISTS Models (
				ID bigint unsigned PRIMARY KEY,
				Name text NOT NULL
			);
END
		$dbh->commit or warn $dbh->errstr;
	}

	unless ($self->_table_exists("Statements${id}")) {
		$dbh->do( <<"END" ) || do { $dbh->rollback; return };
			CREATE TABLE IF NOT EXISTS Statements${id} (
				Subject bigint unsigned NOT NULL,
				Predicate bigint unsigned NOT NULL,
				Object bigint unsigned NOT NULL,
				Context bigint unsigned NOT NULL DEFAULT 0,
				PRIMARY KEY (Subject, Predicate, Object, Context)
			);
END

# 		$dbh->do( "DROP TABLE IF EXISTS Statements${id}" ) || do { $dbh->rollback; return };


#		$dbh->do( "CREATE INDEX idx_${name}_spog ON Statements${id} (Subject,Predicate,Object,Context);", undef, $name ); # || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX `idx_${name}_pogs` ON Statements${id} (Predicate,Object,Context,Subject);", undef, $name ); # || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX `idx_${name}_opcs` ON Statements${id} (Object,Predicate,Context,Subject);", undef, $name ); # || do { $dbh->rollback; return };
		$dbh->do( "CREATE INDEX `idx_${name}_cpos` ON Statements${id} (Context,Predicate,Object,Subject);", undef, $name ); # || do { $dbh->rollback; return };

# 		$dbh->do( "DELETE FROM Models WHERE ID = ${id}") || do { $dbh->rollback; return };
		$dbh->do( "INSERT INTO Models (ID, Name) VALUES (${id}, ?)", undef, $name );
	
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
