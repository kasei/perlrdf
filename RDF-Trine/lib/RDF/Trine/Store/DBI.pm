=head1 NAME

RDF::Trine::Store::DBI - Persistent RDF storage based on DBI

=head1 VERSION

This document describes RDF::Trine::Store::DBI version 1.012

=head1 SYNOPSIS

  use RDF::Trine::Store::DBI;
  
  my $user = 'me';
  my $pass = 'secret';
  my $modelname = 'mymodel';

  # First, construct a DBI connection to your database
  my $dsn = "DBI:mysql:database=perlrdf";
  my $dbh = DBI->connect( $dsn, $user, $pass );
  
  # Second, create a new Store object with the database connection
  # and specifying (by name) which model in the Store you want to use
  my $store = RDF::Trine::Store::DBI->new( $modelname, $dbh );
  
  # Finally, wrap the Store objec into a Model, and use it to access your data
  my $model = RDF::Trine::Model->new($store);
  print $model->size . " RDF statements in store\n";

=head1 DESCRIPTION

RDF::Trine::Store::DBI provides a persistent triple-store using the L<DBI|DBI>
module.

=cut

package RDF::Trine::Store::DBI;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use DBI;
use DBIx::Connector;

use Carp;
use DBI;
use Scalar::Util qw(blessed reftype refaddr);
use Encode;
use Digest::MD5 ('md5');
use Math::BigInt;
use Data::Dumper;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;
use RDF::Trine::Iterator;
use Log::Log4perl;

use RDF::Trine::Error;
use RDF::Trine::Store::DBI::mysql;
use RDF::Trine::Store::DBI::SQLite;
use RDF::Trine::Store::DBI::Pg;

######################################################################

our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<new ( $model_name, $dbh )>

=item C<new ( $model_name, $dsn, $user, $pass )>

Returns a new storage object using the supplied arguments to construct a DBI
object for the underlying database.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<DBI> for this backend.

These keys should also be used:

=over

=item C<name>

The name of the model.

=item C<dsn>

The DBI Data Source Name for the underlying database.

=item C<username>

The username of the database user.

=item C<password>

The password of the database user.

=back

=item C<new_with_object ( $dbi_db )>

Initialize the store with a L<DBI::db> object.

=cut

sub new {
	my $class	= shift;
	my ($dbh, $conn);
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	my $name	= shift || 'model';
	my %args;
	if (scalar(@_) == 0) {
		$l->trace("trying to construct a temporary model");
		my $dsn		= "dbi:SQLite:dbname=:memory:";
		$conn		= DBIx::Connector->new( $dsn, '', '' );
		$class		= 'RDF::Trine::Store::DBI::SQLite';
	} elsif (blessed($_[0]) and $_[0]->isa('DBI::db')) {
		$l->trace("got a DBD handle");
		$dbh		= shift;
		my $name	= $dbh->get_info(17);
		if ($name eq 'MySQL') {
			$class	= 'RDF::Trine::Store::DBI::mysql';
		} elsif ($name eq 'PostgreSQL') {
			$class	= 'RDF::Trine::Store::DBI::Pg';
		} elsif ($name eq 'SQLite') {
			$class	= 'RDF::Trine::Store::DBI::SQLite';
		}
	} elsif (blessed($_[0]) and $_[0]->isa('DBIx::Connector')) {
		$conn	= shift;
	} else {
		my $dsn		= shift;
		my $user	= shift;
		my $pass	= shift;
		if ($dsn =~ /^DBI:mysql:/i) {
			$class	= 'RDF::Trine::Store::DBI::mysql';
		} elsif ($dsn =~ /^DBI:Pg:/i) {
			$class	= 'RDF::Trine::Store::DBI::Pg';
		} elsif ($dsn =~ /^DBI:SQLite:/i) {
			$class	= 'RDF::Trine::Store::DBI::SQLite';
			$user	= '';
			$pass	= '';
		}
		$l->trace("Connecting to $dsn ($user, $pass)");
		$conn		= DBIx::Connector->new( $dsn, $user, $pass );
		unless ($conn) {
			throw RDF::Trine::Error::DatabaseError -text => "Couldn't connect to database: " . DBI->errstr;
		}
	}
	
	my $self	= bless( {
		model_name				=> $name,
		dbh						=> $dbh,
		conn					=> $conn,
		statements_table_prefix	=> 'Statements',
		%args
	}, $class );
	$self->init();
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	my ($model, $dsn, $user, $pass)	= split(';', $config);
	return $class->new( $model, $dsn, $user, $pass );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config->{name},
			    $config->{dsn},
			    $config->{username},
			    $config->{password} );
}

sub _new_with_object {
	my $class	= shift;
	my $obj		= shift;
	return unless (blessed($obj) and $obj->isa('DBI::db'));
	return $class->new( $obj );
}

=item C<< nuke >>

Permanently removes the store and its data. Note that because of this module's
use of the Redland schema, removing a store with this method will only delete
the Statements table and remove the model's entry in the Models table. The node
entries in the Literals, Bnodes, and Resources tables will still exist.

=cut

sub nuke {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	my $id		= _mysql_hash( $name );
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	$dbh->do( "DROP TABLE Statements${id};" ) || do { $l->trace( $dbh->errstr ); return };
	$dbh->do( "DELETE FROM Models WHERE ID = ${id}") || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	return;
}

=item C<< temporary_store >>

=cut

sub temporary_store {
	my $class	= shift;
	my $name	= 'model_' . sprintf( '%x%x%x%x', map { int(rand(16)) } (1..4) );
	my $self	= $class->new( $name, @_ );
	$self->{ remove_store }	= 1;
	$self->init();
	return $self;
}

=item C<< clear_restrictions >>

Clear's the restrictions put on the binding of node types to the different
statement positions. By default, the subject position is restricted to resources
and blank nodes, and the predicate position to only resources. Calling this
method will allow any node type in any statement position.

=cut

sub clear_restrictions {
	my $self	= shift;
	foreach my $pos (qw(subject predicate object context)) {
		$self->{restrictions}{$pos}   = [];
	}
	return;
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
# 		warn "count statements with quad" if ($::debug);
		my $g	= $nodes[3];
		if (blessed($g) and not($g->is_variable)) {
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	my ($subj, $pred, $obj, $context)	= @nodes;
	
	my $var		= 0;
	my $dbh		= $self->dbh;
	my $st		= ($use_quad)
				? RDF::Trine::Statement::Quad->new( map { defined($_) ? $_ : RDF::Trine::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj,$context) )
				: RDF::Trine::Statement->new( map { defined($_) ? $_ : RDF::Trine::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj) );
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	my @vars	= $st->referenced_variables;
	
	my $semantics	= ($use_quad ? 'quad' : 'triple');
	local($self->{context_variable_count})	= 0;
	local($self->{join_context_nodes})		= 1 if (blessed($context) and $context->is_variable);
	my $sql		= $self->_sql_for_pattern( $st, $context, semantics => $semantics, unique => 1 );
	my $sth		= $dbh->prepare( $sql );
	
	$sth->execute();
	
	my $sub		= sub {
NEXTROW:
		my $row	= $sth->fetchrow_hashref;
		return unless (defined $row);
		my @triple;
		my $temp_var_count	= 1;
		my @nodes	= ($st->nodes)[ $use_quad ? (0..3) : (0..2) ];
		foreach my $node (@nodes) {
			if ($node->is_variable) {
				my $nodename	= $node->name;
				my $uri			= $self->_column_name( $nodename, 'URI' );
				my $name		= $self->_column_name( $nodename, 'Name' );
				my $value		= $self->_column_name( $nodename, 'Value' );
				my $node		= $self->_column_name( $nodename, 'Node' );
				if ($row->{ $node } == 0) {
					push( @triple, RDF::Trine::Node::Nil->new() );
				} elsif (defined( my $u = $row->{ $uri })) {
					$u	= decode('utf8', $u);
					push( @triple, RDF::Trine::Node::Resource->new( $u ) );
				} elsif (defined( my $n = $row->{ $name })) {
					push( @triple, RDF::Trine::Node::Blank->new( $n ) );
				} elsif (defined( my $v = $row->{ $value })) {
					my @cols	= map { $self->_column_name( $nodename, $_ ) } qw(Value Language Datatype);
					$cols[0]	= decode('utf8', $cols[0]);
					$cols[2]	= decode('utf8', $cols[2]);
					push( @triple, RDF::Trine::Node::Literal->new( @{ $row }{ @cols } ) );
				} else {
					warn "node isn't nil or a resource, blank, or literal?" . Dumper($row);
					goto NEXTROW;
				}
			} else {
				push(@triple, $node);
			}
		}
		
		my $st	= (@triple == 3)
					? RDF::Trine::Statement->new( @triple )
					: RDF::Trine::Statement::Quad->new( @triple );
		return $st;
	};
	
	return RDF::Trine::Iterator::Graph->new( $sub )
}

sub _column_name {
	my $self	= shift;
	my @args	= @_;
	my $col		= join('_', @args);
	return $col;
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $pattern	= shift;
	my $context	= shift;
	my %args	= @_;
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	$l->trace("get_pattern called for: " . $pattern->sse);
	
	if (my $o = $args{ orderby }) {
		my @ordering	= @$o;
		while (my ($col, $dir) = splice( @ordering, 0, 2, () )) {
			no warnings 'uninitialized';
			unless ($dir =~ /^(ASC|DESC)$/) {
				throw RDF::Trine::Error::MethodInvocationError -text => "The sort direction for key $col must be either 'ASC' or 'DESC' in get_pattern call";
			}
		}
	}
	
	my $dbh		= $self->dbh;
	my @vars	= $pattern->referenced_variables;
	my %vars	= map { $_ => 1 } @vars;
	
	my $sql		= $self->_sql_for_pattern( $pattern, $context, %args );
	$l->debug("get_pattern sql: $sql\n");
	
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	
	my $sub		= sub {
		my $row	= $sth->fetchrow_hashref;
		return unless $row;
		
		my %bindings;
		foreach my $nodename (@vars) {
			my $uri		= $self->_column_name( $nodename, 'URI' );
			my $name	= $self->_column_name( $nodename, 'Name' );
			my $value	= $self->_column_name( $nodename, 'Value' );
			if (defined( my $u = $row->{ $uri })) {
				$u	= decode('utf8', $u);
				$bindings{ $nodename }	 = RDF::Trine::Node::Resource->new( $u );
			} elsif (defined( my $n = $row->{ $name })) {
				$bindings{ $nodename }	 = RDF::Trine::Node::Blank->new( $n );
			} elsif (defined( my $v = $row->{ $value })) {
				my @cols	= map { $self->_column_name( $nodename, $_ ) } qw(Value Language Datatype);
				my ($val,$lang,$dt)	= @{ $row }{ @cols };
				$val	= decode('utf8', $val);
				$dt		= decode('utf8', $dt);
				$bindings{ $nodename }	 = RDF::Trine::Node::Literal->new( $val, $lang, $dt );
			} else {
				$bindings{ $nodename }	= undef;
			}
		}
		return RDF::Trine::VariableBindings->new( \%bindings );
	};
	
	my @args;
	if (my $o = $args{ orderby }) {
		my @ordering	= @$o;
		my @realordering;
		while (my ($col, $dir) = splice( @ordering, 0, 2, () )) {
			if (exists $vars{ $col }) {
				push(@realordering, $col, $dir);
			}
		}
		@args	= ( sorted_by => \@realordering );
	}
	return RDF::Trine::Iterator::Bindings->new( $sub, \@vars, @args )
}


=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $stable	= $self->statements_table;
	my $sql		= "SELECT DISTINCT Context, r.URI AS URI, b.Name AS Name, l.Value AS Value, l.Language AS Language, l.Datatype AS Datatype FROM ${stable} s LEFT JOIN Resources r ON (r.ID = s.Context) LEFT JOIN Literals l ON (l.ID = s.Context) LEFT JOIN Bnodes b ON (b.ID = s.Context) ORDER BY URI, Name, Value;";
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	my $sub		= sub {
		while (my $row = $sth->fetchrow_hashref) {
			return unless defined($row);
			my $uri		= $self->_column_name( 'URI' );
			my $name	= $self->_column_name( 'Name' );
			my $value	= $self->_column_name( 'Value' );
			my $ctx		= $self->_column_name( 'Context' );
			if ($row->{ $ctx } == 0) {
				next;
# 				return RDF::Trine::Node::Nil->new();
			} elsif ($row->{ $uri }) {
				return RDF::Trine::Node::Resource->new( $row->{ $uri } );
			} elsif ($row->{ $name }) {
				return RDF::Trine::Node::Blank->new( $row->{ $name } );
			} elsif (defined $row->{ $value }) {
				my @cols	= map { $self->_column_name( $_ ) } qw(Value Language Datatype);
				return RDF::Trine::Node::Literal->new( @{ $row }{ @cols } );
			} else {
				return;
			}
		}
		return;
	};
	return RDF::Trine::Iterator->new( $sub );
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
	my @nodes	= $stmt->nodes;
	my @values = map { $self->_add_node( $_ ) } @nodes;
	
	if ($stmt->isa('RDF::Trine::Statement::Quad')) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
		}
		$context	= $stmt->context;
	} else {
		push @values, ($context ? $self->_add_node($context) : 0);
	}
	my $sql	= "SELECT 1 FROM ${stable} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?";
	my $sth	= $dbh->prepare( $sql );
	$sth->execute( @values );
	unless ($sth->fetch) {
		my $sql		= sprintf( "INSERT INTO ${stable} (Subject, Predicate, Object, Context) VALUES (?,?,?,?)" );
		my $sth		= $dbh->prepare( $sql );
		$sth->execute(@values);
	}
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $context	= shift;
	my $dbh		= $self->dbh;
	my $stable	= $self->statements_table;
	
	unless (blessed($stmt)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "no statement passed to remove_statement";
	}
	
	if ($stmt->isa( 'RDF::Trine::Statement::Quad' )) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "remove_statement cannot be called with both a quad and a context";
		}
	} else {
		my @nodes	= $stmt->nodes;
		if (blessed($context)) {
			$stmt	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $context );
		} else {
			my $nil	= RDF::Trine::Node::Nil->new();
			$stmt	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $nil );
		}
	}
	
	my @nodes	= $stmt->nodes;
	my $sth		= $dbh->prepare("DELETE FROM ${stable} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?");
	my @values	= map { $self->_mysql_node_hash( $_ ) } (@nodes);
	$sth->execute( @values );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $context	= shift;
	my $dbh		= $self->dbh;
	my $stable	= $self->statements_table;
	
	my (@where, @bind);
	my @keys	= qw(Subject Predicate Object Context);
	foreach my $node ($subj, $pred, $obj, $context) {
		my $key	= shift(@keys);
		if (defined($node)) {
			push(@bind, $node);
			push(@where, "${key} = ?");
		}
	}
	
	my $where	= join(" AND ", @where);
	my $sth		= $dbh->prepare( join(' ', "DELETE FROM ${stable}", ($where ? "WHERE ${where}" : ())) );
	my @values	= map { $self->_mysql_node_hash( $_ ) } (@bind);
	$sth->execute( @values );
}

sub _add_node {
	my $self	= shift;
	my $node	= shift;
	my $hash	= $self->_mysql_node_hash( $node );
	my $dbh		= $self->dbh;
	
	my @cols;
	my $table;
	my %values;
	return $hash if ($node->is_nil);
	if ($node->is_blank) {
		$table	= "Bnodes";
		@cols	= qw(ID Name);
		@values{ @cols }	= ($hash, $node->blank_identifier);
	} elsif ($node->is_resource) {
		$table	= "Resources";
		@cols	= qw(ID URI);
		@values{ @cols }	= ($hash, encode('utf8', $node->uri_value));
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		$table	= "Literals";
		@cols	= qw(ID Value);
		@values{ @cols }	= ($hash, encode('utf8', $node->literal_value));
		if ($node->has_language) {
			push(@cols, 'Language');
			$values{ 'Language' }	= $node->literal_value_language;
		} elsif ($node->has_datatype) {
			push(@cols, 'Datatype');
			$values{ 'Datatype' }	= encode('utf8', $node->literal_datatype);
		}
	}
	
	my $ssql	= "SELECT 1 FROM ${table} WHERE " . join(' AND ', map { join(' = ', $_, '?') } @cols);
	my $sth	= $dbh->prepare( $ssql );
	my @values	= map {"$_"} @values{ @cols };
	$sth->execute( @values );
	unless ($sth->fetch) {
		my $sql	= "INSERT INTO ${table} (" . join(', ', @cols) . ") VALUES (" . join(',',('?')x scalar(@cols)) . ")";
		my $sth	= $dbh->prepare( $sql );
		$sth->execute( @values );
	}
	return $hash;
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
# 		warn "count statements with quad" if ($::debug);
		my $g	= $nodes[3];
		if (blessed($g) and not($g->is_variable)) {
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	my ($subj, $pred, $obj, $context)	= @nodes;
	
	my $dbh		= $self->dbh;
	my $var		= 0;
	my $st		= ($use_quad)
				? RDF::Trine::Statement::Quad->new( map { defined($_) ? $_ : RDF::Trine::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj,$context) )
				: RDF::Trine::Statement->new( map { defined($_) ? $_ : RDF::Trine::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj) );
	my @vars	= $st->referenced_variables;
	
	my $semantics	= ($use_quad ? 'quad' : 'triple');
	my $countkey	= ($use_quad) ? 'count' : 'count-distinct';
	my $sql		= $self->_sql_for_pattern( $st, $context, $countkey => 1, semantics => $semantics );
#	$sql		=~ s/SELECT\b(.*?)\bFROM/SELECT COUNT(*) AS c FROM/smo;
	my $count;
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	$sth->bind_columns( \$count );
	$sth->fetch;
	return $count;
}

=item C<add_uri ( $uri, $named, $format )>

Addsd the contents of the specified C<$uri> to the model.
If C<$named> is true, the data is added to the model using C<$uri> as the
named context.

=cut

=item C<add_string ( $data, $base_uri, $named, $format )>

Addsd the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

=item C<< add_statement ( $statement ) >>

Adds the specified C<$statement> to the underlying model.

=cut

=item C<< remove_statement ( $statement ) >>

Removes the specified C<$statement> from the underlying model.

=cut

=item C<< variable_columns ( $var ) >>

Given a variable name, returns the set of column aliases that store the values
for the column (values for Literals, URIs, and Blank Nodes).

=cut

sub variable_columns {
	my $self	= shift;
	my $var		= shift;
	my $context	= shift;
	
	### ORDERING of these is important to enforce the correct sorting of results
	### based on the SPARQL spec. Bnodes < IRIs < Literals, but since NULLs sort
	### higher than other values, the list needs to be reversed.
	my $r	= $context->{restrict}{$var};
	
	my @cols;
	push(@cols, 'Value') unless ($r->{literal});
	push(@cols, 'URI') unless ($r->{resource});
	push(@cols, 'Name') unless ($r->{blank});
	return map { "${var}_$_" } @cols;
}

=item C<< add_variable_values_joins >>

Modifies the query by adding LEFT JOINs to the tables in the database that
contain the node values (for literals, resources, and blank nodes).

=cut

my %NODE_TYPE_TABLES	= (
						resource	=> ['Resources', 'ljr', 'URI'],
						literal		=> ['Literals', 'ljl', qw(Value Language Datatype)],
						blank		=> ['Bnodes', 'ljb', qw(Name)]
					);
sub add_variable_values_joins {
	my $self	= shift;
	my $context	= shift;
	my $varhash	= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	my @vars	= keys %$varhash;
	my %select_vars	= map { $_ => 1 } @vars;
	my %variable_value_cols;
	
	my $vars	= $context->{vars};
	my $from	= $context->{from_tables};
	my $where	= $context->{where_clauses};
	my $stable	= $self->statements_table;
	
	my @cols;
	my $uniq_count	= 0;
	my (%seen_vars, %seen_joins);
	foreach my $var (grep { not $seen_vars{ $_ }++ } (sort (@vars, keys %$vars))) {
		my $col	= $vars->{ $var };
		unless ($col) {
			throw RDF::Trine::Error::CompilationError -text => "*** Nothing is known about the variable ?${var}";
		}
		
		my $col_table	= (split(/[.]/, $col))[0];
		my ($count)		= ($col_table =~ /\w(\d+)/);
		
		$l->info("var: $var\t\tcol: $col\t\tcount: $count\t\tunique count: $uniq_count");
		
		push(@cols, "${col} AS ${var}_Node") if ($select_vars{ $var });
		my $restricted	= 0;
		my @used_ljoins;
		foreach my $type (reverse sort keys %NODE_TYPE_TABLES) {
			my ($table, $alias, @join_cols)	= @{ $NODE_TYPE_TABLES{ $type } };
			if ($context->{restrict}{$var}{$type}) {
				$restricted	= 1;
				next;
			} else {
				push(@used_ljoins, "${alias}${uniq_count}.$join_cols[0]");
			}
			foreach my $jc (@join_cols) {
				my $column_real_name	= "${alias}${uniq_count}.${jc}";
				my $column_alias_name	= "${var}_${jc}";
				push(@cols, "${column_real_name} AS ${column_alias_name}");
				push( @{ $variable_value_cols{ $var } }, $column_real_name);
				
				foreach my $i (0 .. $#{ $where }) {
					if ($where->[$i] =~ /\b$column_alias_name\b/) {
						$where->[$i]	=~ s/\b${column_alias_name}\b/${column_real_name}/g;
					}
				}
				
			}
		}
		
		foreach my $i (0 .. $#{ $from }) {
			my $f		= $from->[ $i ];
			next if ($from->[ $i ] =~ m/^[()]$/);
			my ($alias)	= ($f =~ m/${stable} (\w\d+)/);	#split(/ /, $f))[1];
			
			if ($alias eq $col_table) {
#				my (@tables, @where);
				foreach my $type (reverse sort keys %NODE_TYPE_TABLES) {
					next if ($context->{restrict}{$var}{$type});
					my ($vtable, $vname)	= @{ $NODE_TYPE_TABLES{ $type } };
					my $valias	= join('', $vname, $uniq_count);
					next if ($seen_joins{ $valias }++);
					
#					push(@tables, "${vtable} ${valias}");
#					push(@where, "${col} = ${valias}.ID");
					$f	.= " LEFT JOIN ${vtable} ${valias} ON (${col} = ${valias}.ID)";
				}
				
#				my $join	= sprintf("LEFT JOIN (%s) ON (%s)", join(', ', @tables), join(' AND ', @where));
#				$from->[ $i ]	= join(' ', $f, $join);
				$from->[ $i ]	= $f;
				next;
			}
		}
		
		if ($restricted) {
			# if we're restricting the left-joins to only certain types of nodes,
			# we need to insure that the rows we're getting back actually have data
			# in the left-joined columns. otherwise, we might end up with data for
			# a URI, but only left-join with Bnodes (for example), and end up with
			# NULL values where we aren't expecting them.
			_add_where( $context, '(' . join(' OR ', map {"$_ IS NOT NULL"} @used_ljoins) . ')' );
		}
		
		$uniq_count++;
	}
	
	return (\%variable_value_cols, @cols);
}

sub _sql_for_pattern {
	my $self		= shift;
	my $pat			= shift;
	my $ctx_node	= shift;
	my %args		= @_;
	
	my @disjunction;
	my @patterns	= $pat;
	my $variables;
	while (my $p = shift(@patterns)) {
		if ($p->isa('RDF::Query::Algebra::Union')) {
			push(@patterns, $p->patterns);
		} else {
			my $pvars	= join('#', sort $p->referenced_variables);
			if (@disjunction) {
				# if we've already got some UNION patterns, make sure the new
				# pattern has the same referenced variables (otherwise the
				# columns of the result are going to come out all screwy
				if ($pvars ne $variables) {
					throw RDF::Trine::Error::CompilationError -text => 'All patterns in a UNION must reference the same variables.';
				}
			} else {
				$variables	= $pvars;
			}
			push(@disjunction, $p);
		}
	}
	
	my @sql;
	foreach my $pattern (@disjunction) {
		my $type		= $pattern->type;
		my $method		= "_sql_for_" . lc($type);
		my $context		= $self->_new_context;
		
# 		warn "*** sql compilation method $method";
		if ($self->can($method)) {
			$self->$method( $pattern, $ctx_node, $context, %args );
			push(@sql, $self->_sql_from_context( $context, %args ));
		} else {
			throw RDF::Trine::Error::CompilationError ( -text => "Don't know how to turn a $type into SQL" );
		}
	}
	return join(' UNION ', @sql);
}

sub _new_context {
	my $self	= shift;
	my $context		= {
						next_alias		=> 0,
						level			=> 0,
						statement_table	=> $self->statements_table,
					};
	return $context;
}

use constant INDENT	=> "\t";
sub _sql_from_context {
	my $self	= shift;
	my $context	= shift;
	my %args	= @_;
	my $vars	= $context->{vars};
	my $from	= $context->{from_tables} || [];
	my $where	= $context->{where_clauses} || [];
	my $unique	= $args{'unique'} ? 1 : 0;
	
	my ($varcols, @cols)	= $self->add_variable_values_joins( $context, $vars );
	unless (@cols) {
		push(@cols, 1);
	}
	
	my $from_clause;
	foreach my $f (@$from) {
		$from_clause	.= ",\n" . INDENT if ($from_clause and $from_clause =~ m/[^(]$/ and $f !~ m/^([)]|LEFT JOIN)/);
		$from_clause	.= $f;
	}
	
	my $where_clause	= @$where ? "WHERE\n"
						. INDENT . join(" AND\n" . INDENT, @$where) : '';
	
	if ($args{ count }) {
		@cols	= ('COUNT(*)');
	}
	if ($args{ 'count-distinct' }) {
		$unique	= 1;
	}
	if ($args{ 'count' }) {
		@cols	= 'COUNT(*)';
	}
	
	my @sql	= (
				"SELECT" . ($unique ? ' DISTINCT' : ''),
				INDENT . join(",\n" . INDENT, @cols),
				"FROM",
				INDENT . $from_clause,
				$where_clause,
			);
	
	if (my $o = $args{ orderby }) {
		my @ordering	= @$o;
		my @sort;
		while (my ($col, $dir) = splice( @ordering, 0, 2, () )) {
			if (exists $vars->{ $col }) {
				push(@sort, map { "$_ $dir" } $self->variable_columns( $col, $context ));
			}
		}
		if (@sort) {
			push(@sql, "ORDER BY " . join(', ', @sort));
		}
	}
#	push(@sql, $self->order_by_clause( $varcols, $level ) );
#	push(@sql, $self->limit_clause( $options ) );
	
	my $sql	= join("\n", grep {length} @sql);
	
	if ($args{ 'count-distinct' }) {
		$sql	= "SELECT COUNT(*) FROM ($sql) AS counttable";
	}
	
# 	warn $sql;
	return $sql;
}

sub _get_level { return $_[0]{level}; }
sub _next_alias { return $_[0]{next_alias}++; }
sub _statements_table { return $_[0]{statement_table}; };
sub _add_from { push( @{ $_[0]{from_tables} }, $_[1] ); }
sub _add_where { push( @{ $_[0]{where_clauses} }, $_[1] ); }
sub _get_var { return $_[0]{vars}{ $_[1] }; }
sub _add_var { $_[0]{vars}{ $_[1] } = $_[2]; }
sub _add_restriction {
	my $context	= shift;
	my $var		= shift;
	my @rests	= @_;
	foreach my $r (@rests) {
		$context->{restrict}{ $var->name }{ $r }++
	}
}

sub _sql_for_filter {
	my $self		= shift;
	my $filter		= shift;
	my $ctx_node	= shift;
	my $context		= shift;
	
	my $expr		= $filter->expr;
	my $pattern		= $filter->pattern;
	my $type		= $pattern->type;
	my $method		= "_sql_for_" . lc($type);
	$self->$method( $pattern, $ctx_node, $context );
	$self->_sql_for_expr( $expr, $ctx_node, $context, @_ );
}

sub _sql_for_expr {
	my $self		= shift;
	my $expr		= shift;
	my $ctx_node	= shift;
	my $context		= shift;
	
	### None of these should affect the context directly, since the expression
	### might be a child of another expression (e.g. "isliteral(?node) || isresource(?node)")
	
	if ($expr->isa('RDF::Query::Expression::Function')) {
		my $func	= $expr->uri->uri_value;
		my @args	= $expr->arguments;
		if ($func eq 'sparql:isliteral' and blessed($args[0]) and $args[0]->isa('RDF::Trine::Node::Variable')) {
			my $node	= $args[0];
			_add_restriction( $context, $node, qw(blank resource) );
		} elsif ($func =~ qr/^sparql:is[iu]ri$/ and blessed($args[0]) and $args[0]->isa('RDF::Trine::Node::Variable')) {
			my $node	= $args[0];
			_add_restriction( $context, $node, qw(blank literal) );
		} elsif ($func =~ qr/^sparql:isblank$/ and blessed($args[0]) and $args[0]->isa('RDF::Trine::Node::Variable')) {
			my $node	= $args[0];
			_add_restriction( $context, $node, qw(literal resource) );
		} elsif ($func eq 'sparql:logical-or') {
			$self->_sql_for_or_expr( $expr, $ctx_node, $context, @_ );
		} else {
			throw RDF::Trine::Error::CompilationError -text => "Unknown function data: " . Dumper($expr);
		}
	} elsif ($expr->isa('RDF::Query::Expression::Binary')) {
		if ($expr->op eq '==') {
			$self->_sql_for_equality_expr( $expr, $ctx_node, $context, @_ );
		} else {
			throw RDF::Trine::Error::CompilationError -text => "Unknown expr data: " . Dumper($expr);
		}
		
	} else {
		throw RDF::Trine::Error::CompilationError -text => "Unknown expr data: " . Dumper($expr);
	}
	return;
}

sub _sql_for_or_expr {
	my $self		= shift;
	my $expr		= shift;
	my $ctx_node	= shift;
	my $context		= shift;
	my @args		= $self->_logical_or_operands( $expr );
	
	my @disj;
	foreach my $e (@args) {
		my $tmp_ctx		= $self->_new_context;
		$self->_sql_for_expr( $e, $ctx_node, $tmp_ctx, @_ );
		my ($var, $val)	= %{ $tmp_ctx->{vars} };
		my $existing_col = _get_var( $context, $var );
		push(@disj, "${existing_col} = $val");
	}
	my $disj	= '(' . join(' OR ', @disj) . ')';
	_add_where( $context, $disj );
}

sub _logical_or_operands {
	my $self	= shift;
	my $expr	= shift;
	my @args	= $expr->operands;
	my @ops;
	foreach my $e (@args) {
		if ($e->isa('RDF::Query::Expression::Function') and $e->uri->uri_value eq 'sparql:logical-or') {
			push(@ops, $self->_logical_or_operands( $e ));
		} else {
			push(@ops, $e);
		}
	}
	return @ops;
}

sub _sql_for_equality_expr {
	my $self		= shift;
	my $expr		= shift;
	my $ctx_node	= shift;
	my $context		= shift;
	
	my @args	= $expr->operands;
	# make sorted[0] be the variable
	my @sorted	= sort { $b->isa('RDF::Trine::Node::Variable') } @args;
	unless ($sorted[0]->isa('RDF::Trine::Node::Variable')) {
		throw RDF::Trine::Error::CompilationError -text => "No variable in equality test";
	}
	unless ($sorted[1]->isa('RDF::Trine::Node') and not($sorted[1]->isa('RDF::Trine::Node::Variable'))) {
		throw RDF::Trine::Error::CompilationError -text => "No RDFNode in equality test";
	}
	
	my $name	= $sorted[0]->name;
	my $id		= $self->_mysql_node_hash( $sorted[1] );
#	$self->_add_sql_node_clause( $id, $sorted[0], $context );
	if (my $existing_col = _get_var( $context, $name )) {
		_add_where( $context, "${existing_col} = $id" );
	} else {
		_add_var( $context, $name, $id );
	}
}

sub _sql_for_triple { &_sql_for_statement; }
sub _sql_for_quad { &_sql_for_statement; }
{
	my %default_restrictions	= (
		subject		=> ['literal'],
		predicate	=> [qw(literal blank)],
		object		=> [],
		context		=> [],
	);
sub _sql_for_statement {
	my $self	= shift;
	my $triple	= shift;
	my $ctx		= shift;
	my $context	= shift;
	my %args	= @_;
	
	my %restrictions = defined $self->{restrictions}
		? %{ $self->{restrictions} }
		: %default_restrictions;

	my $quad	= $triple->isa('RDF::Trine::Statement::Quad');
	no warnings 'uninitialized';
	if ($args{semantics} eq 'triple') {
		$quad	= 0;
	}
	my @posmap	= ($quad)
				? qw(subject predicate object context)
				: qw(subject predicate object);
	my $table		= "s" . _next_alias($context);
	my $stable		= _statements_table($context);
	my $level		= _get_level( $context );
	_add_from( $context, "${stable} ${table}" );
	foreach my $method (@posmap) {
		my $node	= $triple->$method();
		next unless defined($node);
		my $pos		= $method;
		my $col		= "${table}.${pos}";
		if ($node->isa('RDF::Trine::Node::Variable')) {
			_add_restriction( $context, $node, @{ $restrictions{ $method } } );
		}
		$self->_add_sql_node_clause( $col, $node, $context );
	}
	
	unless ($quad) {
		if (defined($ctx)) {
			$self->_add_sql_node_clause( "${table}.Context", $ctx, $context );
		} elsif ($self->{join_context_nodes}) {
			$self->_add_sql_node_clause( "${table}.Context", RDF::Trine::Node::Variable->new( 'sql_ctx_' . ++$self->{ context_variable_count } ), $context );
		}
	}
}}

sub _add_sql_node_clause {
	my $self	= shift;
	my $col		= shift;
	my $node	= shift;
	my $context	= shift;
	if ($node->isa('RDF::Trine::Node::Variable')) {
		my $name	= $node->name;
		if (my $existing_col = _get_var( $context, $name )) {
			_add_where( $context, "$col = ${existing_col}" );
		} else {
			_add_var( $context, $name, $col );
		}
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		my $uri	= $node->uri_value;
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
#		my $id	= $node->blank_identifier;
#		my $b	= "b$level";
#		_add_from( $context, "Bnodes $b" );
#		_add_where( $context, "${col} = ${b}.ID" );
#		_add_where( $context, "${b}.Name = '$id'" );
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
	} elsif ($node->is_nil) {
		_add_where( $context, "${col} = 0" );
	} else {
		throw RDF::Trine::Error::CompilationError( -text => "Unknown node type: " . Dumper($node) );
	}
}

sub _sql_for_bgp {
	my $self	= shift;
	my $bgp		= shift;
	my $ctx		= shift;
	my $context	= shift;
	
	foreach my $triple ($bgp->triples) {
		$self->_sql_for_triple( $triple, $ctx, $context, @_ );
	}
}

sub _sql_for_ggp {
	my $self	= shift;
	my $ggp		= shift;
	my $ctx		= shift;
	my $context	= shift;
	
	my @patterns	= $ggp->patterns;
	throw RDF::Trine::Error::CompilationError -text => "Can't compile an empty GroupGraphPattern to SQL" unless (scalar(@patterns));;
	
	foreach my $p (@patterns) {
		my $type	= $p->type;
		my $method	= "_sql_for_" . lc($type);
		$self->$method( $p, $ctx, $context, @_ );
	}
}

=item C<< _mysql_hash ( $data ) >>

Returns a hash value for the supplied C<$data> string. This value is computed
using the same algorithm that Redland's mysql storage backend uses.

=cut

sub _mysql_hash;
sub _mysql_hash_pp {
	my $data	= encode('utf8', shift);
	my @data	= unpack('C*', md5( $data ));
	my $sum		= Math::BigInt->new('0');
	foreach my $count (0 .. 7) {
		my $data	= Math::BigInt->new( $data[ $count ] ); #shift(@data);
		my $part	= $data << (8 * $count);
#		warn "+ $part\n";
		$sum		+= $part;
	}
#	warn "= $sum\n";
	$sum	=~ s/\D//;	# get rid of the extraneous '+' that pops up under perl 5.6
	return $sum;
}

BEGIN {
	## no critic
	eval "use RDF::Trine::XS;";
	no strict 'refs';
	*{ '_mysql_hash' }	= (RDF::Trine::XS->can('hash'))
		? \&RDF::Trine::XS::hash
		: \&_mysql_hash_pp;
	## use critic
}

=item C<< _mysql_node_hash ( $node ) >>

Returns a hash value (computed by C<_mysql_hash> for the supplied C<$node>.
The hash value is based on the string value of the node and the node type.

=cut

sub _mysql_node_hash {
	my $self	= shift;
	my $node	= shift;
	
#	my @node	= @$node;
#	my ($type, $value)	= splice(@node, 0, 2, ());
	return 0 unless (blessed($node));
	return 0 if ($node->is_nil);
	
	my $data;
	if ($node->isa('RDF::Trine::Node::Resource')) {
		my $value	= $node->uri_value;
		$data	= 'R' . $value;
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		my $value	= $node->blank_identifier;
		$data	= 'B' . $value;
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $value	= $node->literal_value;
		unless (defined($value)) {
			$value	= '';
		}
		my $lang	= $node->literal_value_language || '';
		my $dt		= $node->literal_datatype || '';
		no warnings 'uninitialized';
		$data	= sprintf("L%s<%s>%s", $value, $lang, $dt);
#		warn "($data)";
	} else {
		return;
	}
	my $hash;
	$hash	= _mysql_hash( $data );
	return $hash;
}

=item C<< statements_table >>

Returns the name of the Statements table.

=cut

sub statements_table {
	my $self	= shift;
	my $model	= $self->model_name;
	my $id		= _mysql_hash( $model );
	my $prefix	= $self->{statements_table_prefix};
	return join('', $prefix, $id);
}

=item C<< statements_prefix >>

Returns the prefix for the underlying Statements database table.

=cut

sub statements_prefix {
	my $self	= shift;
	return $self->{ statements_table_prefix };
}

=item C<< set_statements_prefix ( $prefix ) >>

Sets the prefix for the underlying Statements database table.

=cut

sub set_statements_prefix {
	my $self	= shift;
	my $prefix	= shift;
	$self->{ statements_table_prefix }	= $prefix;
}

=item C<< model_name >>

Returns the name of the underlying model.

=cut

sub model_name {
	my $self	= shift;
# 	Carp::confess unless (blessed($self));
	return $self->{model_name};
}

=item C<< make_private_predicate_view ( $prefix, @preds ) >>

=cut

sub make_private_predicate_view {
	my $self	= shift;
	my $prefix	= shift;
	my @preds	= @_;
	
	my $oldtable	= $self->statements_table;
	my $oldpre		= $self->statements_prefix;
	my $model		= $self->model_name;
	my $id			= _mysql_hash( $model );
	
	my $stable		= join('', $prefix, $oldpre, $id);
	my $predlist	= join(', ', map { $self->_mysql_node_hash( $_ ) } (@preds));
	my $sql			= "CREATE VIEW ${stable} AS SELECT * FROM ${oldtable} WHERE Predicate NOT IN (${predlist})";
	
	my $dbh			= $self->dbh;
	$dbh->do( $sql );
	
	return $stable;
}

=item C<< dbh >>

Returns the underlying DBI database handle.

=cut

sub dbh {
	my $self	= shift;
	if (my $conn = $self->{conn}) {
		return $conn->dbh;
	} else {
		my $dbh		= $self->{dbh};
		return $dbh;
	}
}

sub _debug {
	my $self	= shift;
	my $dbh		= $self->{dbh};
	my $name	= $self->model_name;
	my $id		= _mysql_hash( $name );
	my $table	= 'Statements' . $id;
	my $sth		= $dbh->prepare( "SELECT * FROM $table" );
	$sth->execute;
	my $count	= 1;
	while (my $h = $sth->fetchrow_hashref) {
		my ($s,$p,$o,$g)	= @{ $h }{ qw(Subject Predicate Object Context) };
		warn sprintf("[%5d] subj=%-20d  pred=%-20d  obj=%-20d  context=%-20d\n", $count++, $s, $p, $o, $g );
	}
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	my $id		= _mysql_hash( $name );
	my $l		= Log::Log4perl->get_logger("rdf.trine.store.dbi");
	
	unless ($self->_table_exists("Literals")) {
		$dbh->begin_work;
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE Literals (
				ID NUMERIC(20) PRIMARY KEY,
				Value text NOT NULL,
				Language text NOT NULL DEFAULT '',
				Datatype text NOT NULL DEFAULT ''
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE Resources (
				ID NUMERIC(20) PRIMARY KEY,
				URI text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE Bnodes (
				ID NUMERIC(20) PRIMARY KEY,
				Name text NOT NULL
			);
END
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); $dbh->rollback; return };
			CREATE TABLE Models (
				ID NUMERIC(20) PRIMARY KEY,
				Name text NOT NULL
			);
END
		
		$dbh->commit or warn $dbh->errstr;
	}
	
	unless ($self->_table_exists("Statements${id}")) {
		$dbh->do( <<"END" ) || do { $l->trace( $dbh->errstr ); return };
			CREATE TABLE Statements${id} (
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

sub _table_exists {
	my $self	= shift;
	my $name	= shift;
	my $dbh		= $self->dbh;
	my $type	= 'TABLE';
	my $sth		= $dbh->table_info(undef, undef, $name, 'TABLE');
	my $row		= $sth->fetchrow_hashref;
	return ref($row) ? 1 : 0;
}

sub _cleanup {
	my $self	= shift;
	if (my $dbh = $self->dbh) {
		my $name	= $self->{model_name};
		my $id		= _mysql_hash( $name );
		if ($self->{ remove_store }) {
			$dbh->do( "DROP TABLE `Statements${id}`;" );
			$dbh->do( "DELETE FROM Models WHERE Name = ?", undef, $name );
		}
	}
}

sub _begin_bulk_ops {
	my $self			= shift;
	my $dbh				= $self->dbh;
	$dbh->{AutoCommit}	= 0;
}

sub _end_bulk_ops {
	my $self			= shift;
	my $dbh				= $self->dbh;
	unless ($dbh->{AutoCommit}) {
		$dbh->commit;
	}
	$dbh->{AutoCommit}	= 1;
}

sub DESTROY {
	my $self	= shift;
	our $IGNORE_CLEANUP;
	if ($IGNORE_CLEANUP) {
		$self->dbh->{InactiveDestroy}	= 1;
	} else {
		$self->_cleanup;
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






DROP TABLE Bnodes;
DROP TABLE Literals;
DROP TABLE Models;
DROP TABLE Resources;
DROP TABLE Statements15799945864759145248;
CREATE TABLE Literals (
    ID bigint unsigned PRIMARY KEY,
    Value longtext NOT NULL,
    Language text NOT NULL,
    Datatype text NOT NULL
);
CREATE TABLE Resources (
    ID bigint unsigned PRIMARY KEY,
    URI text NOT NULL
);
CREATE TABLE Bnodes (
    ID bigint unsigned PRIMARY KEY,
    Name text NOT NULL
);
CREATE TABLE Models (
    ID bigint unsigned PRIMARY KEY,
    Name text NOT NULL
);
CREATE TABLE Statements15799945864759145248 (
    Subject bigint unsigned NOT NULL,
    Predicate bigint unsigned NOT NULL,
    Object bigint unsigned NOT NULL,
    Context bigint unsigned NOT NULL
);
INSERT INTO Models (ID,Name) VALUES (15799945864759145248, "model");
