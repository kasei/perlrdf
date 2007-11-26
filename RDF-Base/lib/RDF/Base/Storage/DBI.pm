# RDF::Base::Storage::DBI
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Storage::DBI - An RDF storage backend using DBI and the Redland schema.


=head1 VERSION

This document describes RDF::Base::Storage::DBI version 0.0.1

=head1 SYNOPSIS

    use RDF::Base::Storage::DBI;
    my $dbi = new RDF::Base::Storage::DBI;
    $dbi->add_statement( $s, $p, $o );
    my $iterator = $dbi->get_statements( $s, $p, undef );

=head1 DESCRIPTION

RDF::Base::Storage::DBI implements an RDF storage backend with DBI using the
RDF::Base::Storage API. The database schema used is from the Redland MySQL driver.
This module should work with any DBD module that implements standard SQL.
This includes SQLite, MySQL, and PostgreSQL. For more information, see
L<RDF::Base::Storage>.

=cut

package RDF::Base::Storage::DBI;

our $debug;
BEGIN { $debug		= 0; }
use version; our $VERSION = "0.001";

use strict;
use warnings;
use base qw(DynaLoader RDF::Base::Storage);


use DBI;
use Carp;
use Error;
use Config;
use Math::BigInt;
use Data::Dumper;
use Digest::MD5 ('md5');
use Scalar::Util qw(blessed);
use Encode qw(encode_utf8 decode_utf8);

use RDF::Base;
use RDF::SPARQLResults;

supports RDF::Base::Storage 'multi_get';
supports RDF::Base::Storage 'ordered-get';
supports RDF::Base::Storage 'efficient-counts';

our %supports;
# use Data::Dumper;
# warn Dumper(\%supports);

# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< new ( $dbh, $model_name ) >>

Returns a new RDF storage object for the specified RDBMS triplestore.

=cut

sub new {
	my $class	= shift;
	my $dbh		= shift;
	my $model	= shift;
	
	my $self	= {};
	
	$model		= 'model' unless defined($model);
	unless (defined($dbh)) {
		require File::Temp;
		my (undef, $file)	= File::Temp::tempfile();
		$self->{file}	= $file;
		$dbh	= DBI->connect("dbi:SQLite:dbname=${file}");
		_create_model( $dbh, $model );
	}
	
	throw Error unless (blessed($dbh) and $dbh->isa('DBI::db'));
	
	my $id		= _get_model_id( $dbh, $model );
	unless ($id) {
		$id		= _create_model( $dbh, $model );
#		warn $id;
# 		warn "Model '${model}' doesn't exist. You may create it with the 'new' flag to the Mysql storage constructor\n";
	}
	
	$self->{ dbh }		= $dbh;
	$self->{ name }		= $model;
	$self->{ number }	= $id;
	
	return bless( $self, $class);
}

=item C<< add_statement ( $statement ) >>

=item C<< add_statement ( $subject, $predicate, $object ) >>

Adds the specified statement to the stored RDF graph.
C<$statement> must be a RDF::Base::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Query::Node objects.

=cut

sub add_statement {
	my $self	= shift;
	my ($s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
	}
	
	my $model	= $self->model_number;
	my $dbh		= $self->dbh;
	
	my @ids;
	foreach my $node ($s, $p, $o) {
		my $id	= $self->_add_node( $node );
		push(@ids, $id);
	}
	
	my $context	= 0;
	if ($c) {
		$context	= _mysql_node_hash( $c );
	}
	
	my $sql		= sprintf(
					"INSERT INTO Statements%s (Subject, Predicate, Object, Context) VALUES (%s, %s, %s, %s)",
					$model,
					@ids,
					$context
				);
	
	my $insert	= $dbh->prepare_cached( $sql );
	$insert->execute();
	return 1;
}


=item C<< remove_statement ( $statement ) >>

=item C<< remove_statement ( $subject, $predicate, $object ) >>

Removes the specified statement from the stored RDF graph.
C<$statement> must be a RDF::Base::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Query::Node objects.

=cut

sub remove_statement {
	my $self	= shift;
	my ($s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
	}
	
	my $model	= $self->model_number;
	my $dbh		= $self->dbh;
	
	my @ids;
	foreach my $node ($s, $p, $o) {
		my $id	= $self->_add_node( $node );
		push(@ids, $id);
	}
	
	my $context	= 0;
	if ($c) {
		$context	= _mysql_node_hash( $c );
	}
	
	my $sql		= sprintf(
					"DELETE FROM Statements%s WHERE Subject = %s AND Predicate = %s AND Object = %s AND Context = %s",
					$model,
					@ids,
					$context
				);
	
	my $remove	= $dbh->prepare_cached( $sql );
	$remove->execute();
	return 1;
}


=item C<< exists_statement ( $statement ) >>

=item C<< exists_statement ( $subject, $predicate, $object ) >>

Returns true if the specified statement exists in the stored RDF graph.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Query::Node objects.

=cut

sub exists_statement {
	my $self	= shift;
	my ($s, $p, $o);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
	}
	
	my $dbh		= $self->dbh;
	my $stream	= $self->get_statements($s, $p, $o);
	my $data	= $stream->();
	return $data ? 1 : 0;
}

=item C<< count_statements ( $statement ) >>

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns the number of matching statement that exists in the stored RDF graph.
C<$statement> must be a RDF::Base::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Query::Node objects.

=cut

sub count_statements {
	my $self			= shift;
	
	my ($s, $p, $o);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
	}
	
	my ($sql, @bind)	= $self->get_sql($s, $p, $o, count => 1);
	
	my $dbh		= $self->dbh;
	my $sth		= $dbh->prepare( $sql );
	
	$sth->execute( @bind );
	my ($count)	= $sth->fetchrow_array;
	
	return $count;
}


=item C<< get_statements ( $statement ) >>

=item C<< get_statements ( $subject, $predicate, $object ) >>

Returns an iterator object of all statements matching the specified statement.
C<$statement> must be a RDF::Base::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be either undef (to match any node)
or RDF::Query::Node objects.

=cut

sub get_statements {
	my $self			= shift;
	
	my ($s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
	}
	
#	{
#		no warnings 'uninitialized';
#		warn "get_statements: $self ($s, $p, $o, $c)\n";
#	}
	
	my $dbh				= $self->dbh;
	my ($sql, @bind)	= $self->get_sql( $s, $p, $o, @_ );
	if ($sql) {
		my $sth		= $dbh->prepare( $sql );
		$sth->execute( @bind );
		my $stream	= $self->wrap_results( $sth, qw(subj pred obj) );
		my $code	= sub {	# XXX replace with C<< smap {} $stream >>
			my @nodes	= $stream->();
			if (@nodes) {
				my %args;
				@args{ qw(subject predicate object) }	= @nodes;
				my $st		= RDF::Base::Statement->new( %args );
				return $st;
			} else {
				return;
			}
		};
		
		return RDF::SPARQLResults::Graph->new( $code );
	} else {
		return sub { undef };
	}
}



=item C<< wrap_results ( $sth, @fields ) >>

Wraps the results from a DBI statement handle with an iterator closure.
Each row is turned into a list of RDF::Query::Node objects, based on the named
C<< @fields >> (often just qw(subject predicate object)).

=cut

sub wrap_results {
	my $self		= shift;
	my $sth			= shift;
	my @fields		= @_;
	my $dbh			= $self->dbh;
	
	my $finished	= 0;
	my $stream	= sub {
		return if ($finished);
		if (@_ and $_[0] eq 'close') {
			$sth->finish if ($sth);
			$finished	= 1;
			return;
		}
		my $data	= $sth->fetchrow_hashref;
		
		unless ($data) {
			$finished	= 1;
			return;
		}
		
		my @nodes;
		foreach my $pos (@fields) {
			my $node;
			if (defined(my $uri = $data->{"${pos}_URI"})) {
				$node	= RDF::Query::Node::Resource->new( uri => $uri );
			} elsif (defined(my $name = $data->{"${pos}_Name"})) {
				$node	= RDF::Query::Node::Blank->new( name => $name );
			} elsif (defined(my $value = $data->{"${pos}_Value"})) {
				my %args;
				if (my $lang = $data->{"${pos}_Language"}) {
					$args{ language }	= $lang;
				}
				if (my $dt = $data->{"${pos}_Datatype"}) {
					$args{ datatype }	= $dt;
				}
				
				$node		= RDF::Query::Node::Literal->new( value => decode_utf8( $value ), %args );
			} else {
				warn "Uh oh.";
				warn Dumper($data);
			}
			push(@nodes, $node);
		}
		
		return @nodes;
	};
	return $stream;
}


=begin private

=item C<< dbh >>

Returns the database handle.

=end private

=cut

sub dbh {
	my $self	= shift;
	return $self->{dbh};
}

=begin private

=item C<< model_name >>

Returns the model name.

=end private

=cut

sub model_name {
	my $self	= shift;
	return $self->{name};
}

=begin private

=item C<< model_number >>

Returns the model number.

=end private

=cut

sub model_number {
	my $self	= shift;
	return $self->{number};
}

=begin private

=item C<< get_sql ( $subject, $predicate, $object, %args ) >>

Returns a SQL statement and a list of variable bindings for querying the
specified C<$subject>, C<$predicate>, and C<$object>. If C<$args{ count }> is
true, the query will return a single row containing a count of matching
statements. Otherwise, the query will return rows with 'Subject', 'Predicate'
and 'Object' fields that represent the hashed ID value of the matching RDF node.

=end private

=cut

sub get_sql {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	my %args	= @_;
	my @triple	= ($s, $p, $o);
	
	my $dbh		= $self->dbh;
	my $mnum	= $self->model_number;
	
	my @where;
	my @bind;
	my @map		= qw(Subject Predicate Object);
	foreach my $i (0 .. 2) {
		my $node	= $triple[$i];
		my $id;
		if (blessed($node) and $node->is_node) {
			$id	= _mysql_node_hash( $node );
			$node->{_mysql_ID}	= $id;
			$self->{cache}{$id}	= $node;
			push(@where, join(' ', $map[$i], '=', $id));
		}
	}
	
	my ($cols);
	my $from	= "Statements${mnum} s";
	if ($args{count}) {
		$cols	= 'COUNT(*)';
	} else {
		$cols	= <<"END";
    Subject,
        sr.URI AS "subj_URI",
        sb.Name AS "subj_Name",
    Predicate,
        pr.URI AS "pred_URI",
    Object,
        jr.URI AS "obj_URI",
        jb.Name AS "obj_Name",
        jl.Value AS "obj_Value",
        jl.Language AS "obj_Language",
        jl.Datatype AS "obj_Datatype"
END
		$from	.= <<"END";
    LEFT JOIN Resources sr ON sr.ID = s.Subject
    LEFT JOIN Bnodes sb ON sb.ID = s.Subject
    LEFT JOIN Resources pr ON pr.ID = s.Predicate
    LEFT JOIN Resources jr ON jr.ID = s.Object
    LEFT JOIN Bnodes jb ON jb.ID = s.Object
    LEFT JOIN Literals jl ON jl.ID = s.Object
END
	}
	
	my $sql	= <<"END";
SELECT
	${cols}
FROM ${from}
END
	if (@where) {
		$sql	.= " WHERE " . join(' AND ', @where);
	}
	warn $sql if ($debug > 1);
	return ($sql, @bind);
}


=item C<< multi_get ( triples => \@triples, order => $field ) >>

Returns a RDF::SPARQLResults::Bindings iterator based on the simple
graph pattern expressed by C<< \@triples >>. Results may be sorted by the
named C<< $field >>.

=cut

sub multi_get {
	my $self			= shift;
	
	my $dbh				= $self->dbh;
	my ($sql, @vars)	= $self->get_multi_sql( @_ );
	
	if ($sql) {
		my $sth		= $dbh->prepare( $sql );
		$sth->execute();
		my $stream	= $self->wrap_results( $sth, @vars );
		my $code	= sub {	# XXX replace with C<< smap {} $stream >>
						my @nodes	= $stream->();
						if (@nodes) {
							my %args;
							@args{ @vars }	= @nodes;
							return \%args;
						} else {
							return;
						}
					};
		return RDF::SPARQLResults::Bindings->new( $code );
	} else {
		return RDF::SPARQLResults::Bindings->new();
	}
}

=begin private

=item C<< get_multi_sql ( triples => \@triples, order => $field ) >>

Returns the SQL to retrieve results for the simple graph pattern expressed by
C<< \@triples >>. Results may be sorted by the named C<< $field >>.

=end private

=cut

sub get_multi_sql {
	my $self	= shift;
	my %args	= @_;
	my $triples	= $args{ triples };
	my $order	= $args{ order };
	
	my $mnum	= $self->model_number;
	my $sts		= "Statements${mnum}";
	
	my (@cols, @from, @where, @vars, %vars);
	my %order_columns;
	my $count	= 0;
	foreach my $triple (@$triples) {
		my $join	= 's' . $count++;
		my $from	= "${sts} $join";
		foreach my $col (qw(Subject Predicate Object)) {
			my $method	= lc($col);
			
			my $node	= $triple->$method();
			if ($node->is_resource) {
				my $hash	= _mysql_node_hash( $node );
				push(@where, "${join}.${col} = ${hash}");
			} elsif ($node->is_literal) {
				my $hash	= _mysql_node_hash( $node );
				push(@where, "${join}.${col} = ${hash}");
			} elsif ($node->is_blank) {
				my $hash	= _mysql_node_hash( $node );
				push(@where, "${join}.${col} = ${hash}");
			} elsif ($node->is_variable) {
				my $name		= $node->name;
				if (my $var = $vars{ $name }) {
					push(@where, "${join}.${col} = ${var}");
				} else {
					$vars{ $name }	= "${join}.${col}";
					push(@vars, $name);
					
					my $ljoin	= 'l' . $count++;
					my $rjoin	= 'r' . $count++;
					my $bjoin	= 'b' . $count++;
					push(@cols, "${join}.${col} AS var_${name}");
					push(@cols, qq(${ljoin}.Language AS "${name}_Language"));
					push(@cols, qq(${ljoin}.Datatype AS "${name}_Datatype"));
					push(@cols, qq(${ljoin}.Value AS "${name}_Value"));
					push(@cols, qq(${rjoin}.URI AS "${name}_URI"));
					push(@cols, qq(${bjoin}.Name AS "${name}_Name"));
					$from	.= " LEFT JOIN Literals ${ljoin} ON ${join}.${col} = ${ljoin}.ID"
							. " LEFT JOIN Resources ${rjoin} ON ${join}.${col} = ${rjoin}.ID"
							. " LEFT JOIN Bnodes ${bjoin} ON ${join}.${col} = ${bjoin}.ID";
					$order_columns{ $name }	= join(', ', @cols[ $#cols - 2 .. $#cols ]);
				}
			} else {
				warn "Unknown node type. " . Dumper($node);
			}
		}
		push(@from, $from);
	}
	
	my $sql	= sprintf(
				"SELECT %s FROM %s WHERE %s",
				join(', ', @cols),
				join(', ', @from),
				join(' AND ', @where)
			);

	if ($order) {
		my @order	= (ref($order) ? @$order : $order);
		$sql	.= " ORDER BY " . join(', ', map { $vars{ $_ } } @order);
	}
	
	return ($sql, @vars);
}

=begin private

=item C<< _add_node ( $node ) >>

Adds the specified C<$node> to the database node tables (Resources, Bnodes, Literals).

=end private

=cut

sub _add_node {
	my $self	= shift;
	my $node	= shift;
	my $dbh		= $self->dbh;
	
	if (blessed($node) and $node->is_node) {
		my ($sql, @bind);
		my $id	= _mysql_node_hash( $node );

		if ($node->is_resource) {
			my $sql	= 'SELECT ID FROM Resources WHERE URI = ?';
			my $sth	= $dbh->prepare($sql);
			$sth->execute( $node->uri_value );
			unless ($sth->fetchrow_array) {
				my $sth	= $dbh->prepare_cached( "INSERT INTO Resources (ID, URI) VALUES ($id, ?)" );
				$sth->execute( $node->uri_value );
			}
			return $id;
		} elsif ($node->is_blank) {
			my $name	= $node->blank_identifier;
			$sql	= 'SELECT ID FROM Bnodes WHERE Name = ?';
			my $sth	= $dbh->prepare($sql);
			$sth->execute( $name );
			unless ($sth->fetchrow_array) {
				my $sth	= $dbh->prepare_cached( "INSERT INTO Bnodes (ID, Name) VALUES ($id, ?)" );
				$sth->execute( $name );
			}
			return $id;
		} elsif ($node->is_literal) {
			my @lwhere	= ('Value = ?');
			push(@bind, ($node->literal_value));
			my ($lang, $dt);
			if ($lang = $node->language) {
				warn "Literal language: $lang" if ($debug > 1);
				$dt		= '';
			} elsif ($dt = $node->datatype) {
				warn "Literal datatype: $dt" if ($debug > 1);
				$lang	= '';
			} else {
				$dt		= '';
				$lang	= '';
			}

			push(@lwhere, 'Datatype = ?');
			push(@bind, $dt);
			
			push(@lwhere, 'Language = ?');
			push(@bind, $lang);
			
			my $sql	= 'SELECT ID FROM Literals WHERE ' . join(' AND ', @lwhere);
			my $sth	= $dbh->prepare($sql);
			$sth->execute( @bind );
			unless ($sth->fetchrow_array) {
				my $sth	= $dbh->prepare_cached( "INSERT INTO Literals (ID, Value, Language, Datatype) VALUES ($id, ?, ?, ?)" );
				$sth->execute( $node->literal_value, $lang, $dt );
			}
			return $id;
		} else {
			warn "Cannot create node in database '" . $node->as_string . "'" if ($debug);
			return undef;
		}
		return $id;
	} else {
		carp "Node is not a known type";
		Carp::cluck Dumper($node);
		return;
	}
}



=begin private

=item C<< _get_model_id ( $dbh, $model ) >>

Returns the identifier for the named C<$model>.

=end private

=cut

sub _get_model_id {
	my $dbh		= shift;
	my $model	= shift;
	Carp::confess unless ($dbh);	# XXX
	my $sth		= $dbh->prepare( 'SELECT COUNT(ID) FROM Models WHERE Name = ?' );
	if ($sth) {
		$sth->execute( $model );
		my ($count)	= $sth->fetchrow_array;
		if ($count) {
			return _mysql_hash( $model );
		} else {
			return;
		}
	} else {
		return;
	}
}


=begin private

=item C<< _create_model ( $dbh, $model_name ) >>

Imports the Redland schema to the database specified by C<$dbh>, and creates
a new named model.

=end private

=cut

sub _create_model {
	my $dbh		= shift;
	my $model	= shift;
	my $id		= _mysql_hash( $model );
	
	$dbh->begin_work;
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Statements${id} (
            Subject bigint unsigned NOT NULL,
            Predicate bigint unsigned NOT NULL,
            Object bigint unsigned NOT NULL,
            Context bigint unsigned NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Literals (
            ID bigint unsigned PRIMARY KEY,
            Value longtext NOT NULL,
            Language text NOT NULL,
            Datatype text NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Resources (
            ID bigint unsigned PRIMARY KEY,
            URI text NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Bnodes (
            ID bigint unsigned PRIMARY KEY,
            Name text NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Models (
            ID bigint unsigned PRIMARY KEY,
            Name text NOT NULL
        );
END
    
	my $msth    = $dbh->prepare( "INSERT INTO Models (ID, Name) VALUES (${id}, ?)" );
	$msth->execute( $model ) || do { $dbh->rollback; return undef };
	
	$dbh->commit;
    return $id;
}

=begin private

=item C<< _mysql_node_hash ( $node ) >>

Returns the MD5 hash of the specified C<$node> object.
C<$node> must be an RDF::Query::Node object.

=end private

=cut

sub _mysql_node_hash {
	my $node	= Params::Coerce::coerce( 'RDF::Query::Node', shift );
	my $data;
	if ($node->is_resource) {
		$data	= 'R' . $node->uri_value;
	} elsif ($node->is_blank) {
		$data	= 'B' . $node->blank_identifier;
	} elsif ($node->is_literal) {
		$data	= 'L' . $node->literal_value . '<';
		if (my $lang = $node->language) {
			$data	.= $lang . '>';
		} elsif (my $dt = $node->datatype) {
			$data	.= '>' . $dt;
		} else {
			$data	.= '>';
		}
	} else {
		return;
	}
	
	return _mysql_hash( $data );
}




=begin private

=item C<< _mysql_hash ( $data ) >>

Returns the MD5 hash of the specified C<$data> string.

=end private

=cut

sub _mysql_hash {
	my $data	= shift;
	my $md5		= md5( encode_utf8( $data ) );
	my $hash;
	if ($Config{ d_int64_t }) {
		$hash	= _c( $md5 );
	} else {
		$hash	= _p( $md5 );
	}
	return $hash;
}

sub _p {
	my $md5	= shift;
	my @data	= unpack('C*', $md5);
	my $sum		= Math::BigInt->new('0');
	my $count	= 0;
	for (my $count = 0; $count < 8; $count++) {	# limit to 64 bits
		my $data	= Math::BigInt->new('0') + shift(@data);
		$sum		+= $data << (8 * $count);
	}
	return $sum;
}





sub DESTROY {
    my $self    = shift;
    if (exists($self->{file})) {
        unlink($self->{file});
    }
}


1; # Magic true value required at end of module
__END__

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
  
RDF::Base::Storage::DBI requires no configuration files or environment variables.


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


