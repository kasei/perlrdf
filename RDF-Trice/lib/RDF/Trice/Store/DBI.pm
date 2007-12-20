=head1 NAME

RDF::Store::DBI - [One line description of module's purpose here]


=head1 VERSION

This document describes RDF::Store::DBI version 0.002


=head1 SYNOPSIS

    use RDF::Store::DBI;

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

package RDF::Store::DBI;

use strict;
use warnings;

use DBI;
use Carp;
use Error;
use DBI;
use File::Temp;
use Scalar::Util qw(blessed reftype);
use Digest::MD5 ('md5');
use Math::BigInt;
use Data::Dumper;
use RDF::Query::Node;
use RDF::Query::Algebra;
use RDF::Iterator;

our $VERSION	= "0.003";
use constant DEBUG	=> 0;
our $debug		= DEBUG;



=head1 METHODS

=over 4

=item C<new ( $model_name, $dbh )>

=item C<new ( $model_name, $dsn, $user, $pass )>

Returns a new storage object using the supplied arguments to construct a DBI
object for the underlying database.

=cut

sub new {
	my $class	= shift;
	my $dbh;
	
	my $name	= shift || 'model';
	my %args;
	if (scalar(@_) == 0) {
		warn "trying to construct a temporary model" if (DEBUG);
		my $file	= File::Temp->new;
		$file->unlink_on_destroy( 1 );
		my $dsn		= "dbi:SQLite:dbname=" . $file->filename;
		$dbh		= DBI->connect( $dsn, '', '' );
	} elsif (blessed($_[0]) and $_[0]->isa('DBI::db')) {
		warn "got a DBD handle" if (DEBUG);
		$dbh		= shift;
	} else {
		my $dsn		= shift;
		my $user	= shift;
		my $pass	= shift;
		warn "Connecting to $dsn ($user, $pass)" if (DEBUG);
		$dbh		= DBI->connect( $dsn, $user, $pass );
	}
	my $self	= bless( { model_name => $name, dbh => $dbh, %args }, $class );
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


=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $context	= shift;
	
	my $dbh		= $self->dbh;
	my $triple	= RDF::Query::Algebra::Triple->new( $subj, $pred, $obj );
	my @vars	= $triple->referenced_variables;
	
	my $sql		= $self->_sql_for_pattern( $triple, $context, @_ );
#	warn $sql;
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	
#	my ($ss, $sp, $so);
#	$sth->bind_columns( \$ss, \$sp, \$so );
	my $sub		= sub {
		my $row	= $sth->fetchrow_hashref;
		return undef unless (defined $row);
		
		my @triple;
		foreach my $node ($triple->nodes) {
			if ($node->is_variable) {
				my $name	= $node->name;
				my $prefix	= $name . '_';
				if (defined $row->{ "${prefix}URI" }) {
					push( @triple, RDF::Query::Node::Resource->new( $row->{"${prefix}URI" } ) );
				} elsif (defined $row->{ "${prefix}Name" }) {
					push( @triple, RDF::Query::Node::Blank->new( $row->{"${prefix}Name" } ) );
				} else {
					push( @triple, RDF::Query::Node::Literal->new( @{ $row }{map {"${prefix}$_"} qw(Value Language Datatype) } ) );
				}
			} else {
				push(@triple, $node);
			}
		}
		my $triple	= RDF::Query::Algebra::Triple->new( @triple );
		return $triple;
	};
	
	return RDF::Iterator::Graph->new( $sub )
}


=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $pattern	= shift;
	my $context	= shift;
	my %args	= @_;
	
	if (my $o = $args{ orderby }) {
		my @ordering	= @$o;
		while (my ($col, $dir) = splice( @ordering, 0, 2, () )) {
			no warnings 'uninitialized';
			unless ($dir =~ /^(ASC|DESC)$/) {
				throw Error -text => 'Direction must be ASC or DESC in get_pattern call';
			}
		}
	}
	
	my $dbh		= $self->dbh;
	my @vars	= $pattern->referenced_variables;
	my %vars	= map { $_ => 1 } @vars;
	
	my $sql		= $self->_sql_for_pattern( $pattern, $context, %args );
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	
	my $sub		= sub {
		my $row	= $sth->fetchrow_hashref;
		return unless $row;
		
		my %bindings;
		foreach my $name (@vars) {
			my $prefix	= $name . '_';
			if (defined $row->{ "${prefix}URI" }) {
				$bindings{ $name }	 = RDF::Query::Node::Resource->new( $row->{"${prefix}URI" } );
			} elsif (defined $row->{ "${prefix}Name" }) {
				$bindings{ $name }	 = RDF::Query::Node::Blank->new( $row->{"${prefix}Name" } );
			} else {
				$bindings{ $name }	 = RDF::Query::Node::Literal->new( @{ $row }{map {"${prefix}$_"} qw(Value Language Datatype) } );
			}
		}
		return \%bindings;
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
	return RDF::Iterator::Bindings->new( $sub, \@vars, @args )
}


=item C<< get_contexts >>


=cut

sub get_contexts {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $model	= $self->model_name;
	my $id		= _mysql_hash( $model );
 	my $sql		= "SELECT DISTINCT Context, r.URI AS URI, b.Name AS Name, l.Value AS Value, l.Language AS Language, l.Datatype AS Datatype FROM Statements${id} s LEFT JOIN Resources r ON (r.ID = s.Context) LEFT JOIN Literals l ON (l.ID = s.Context) LEFT JOIN Bnodes b ON (b.ID = s.Context) WHERE Context != 0;";
 	my $sth		= $dbh->prepare( $sql );
 	$sth->execute();
 	my $sub		= sub {
 		my $row	= $sth->fetchrow_hashref;
 		if ($row->{URI}) {
 			return RDF::Query::Node::Resource->new( $row->{URI} );
 		} elsif ($row->{Name}) {
 			return RDF::Query::Node::Blank->new( $row->{Name} );
 		} elsif (defined $row->{Value}) {
 			return RDF::Query::Node::Literal->new( @{ $row }{qw(Value Language Datatype)} );
 		} else {
 			return;
 		}
 	};
 	return RDF::Iterator->new( $sub );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $context	= shift;
	my $dbh		= $self->dbh;
	my $model	= $self->model_name;
	my $id		= _mysql_hash( $model );
	my @nodes	= $stmt->nodes;
	foreach my $n (@nodes) {
		$self->_add_node( $n );
	}

	my $cid		= do {
		if ($context) {
			$self->_add_node( $context );
			$self->_mysql_node_hash( $context );
		} else {
			0
		}
	};
	
	my @values	= map { $self->_mysql_node_hash( $_ ) } @nodes;
	my $sql	= "SELECT 1 FROM Statements${id} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?";
	my $sth	= $dbh->prepare( $sql );
	$sth->execute( @values, $cid );
	unless ($sth->fetch) {
		my $sth		= $dbh->prepare("INSERT INTO Statements${id} (Subject, Predicate, Object, Context) VALUES (?,?,?,?)");
		$sth->execute( @values, $cid );
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
	my $model	= $self->model_name;
	my $id		= _mysql_hash( $model );
	my @nodes	= $stmt->nodes;
	my $sth		= $dbh->prepare("DELETE FROM Statements${id} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?");
	my @values	= map { $self->_mysql_node_hash( $_ ) } (@nodes, $context);
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
	if ($node->is_blank) {
		$table	= "Bnodes";
		@cols	= qw(ID Name);
		@values{ @cols }	= ($hash, $node->blank_identifier);
	} elsif ($node->is_resource) {
		$table	= "Resources";
		@cols	= qw(ID URI);
		@values{ @cols }	= ($hash, $node->uri_value);
	} elsif ($node->is_literal) {
		$table	= "Literals";
		@cols	= qw(ID Value);
		@values{ @cols }	= ($hash, $node->literal_value);
		if ($node->has_language) {
			push(@cols, 'Language');
			$values{ 'Language' }	= $node->literal_value_language;
		} elsif ($node->has_datatype) {
			push(@cols, 'Datatype');
			$values{ 'Datatype' }	= $node->literal_datatype;
		}
	}
	
	my $sql	= "SELECT 1 FROM ${table} WHERE " . join(' AND ', map { join(' = ', $_, '?') } @cols);
	my $sth	= $dbh->prepare( $sql );
	$sth->execute( @values{ @cols } );
	unless ($sth->fetch) {
		my $sql	= "INSERT INTO ${table} (" . join(', ', @cols) . ") VALUES (" . join(',',('?')x scalar(@cols)) . ")";
		my $sth	= $dbh->prepare( $sql );
		$sth->execute( map "$_", @values{ @cols } );
	}
}

=item C<count_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $context	= shift;
	
	my $dbh		= $self->dbh;
	my $var		= 0;
	my $triple	= RDF::Query::Algebra::Triple->new( map { defined($_) ? $_ : RDF::Query::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj) );
	my @vars	= $triple->referenced_variables;
	
	my $sql		= $self->_sql_for_pattern( $triple, $context, count => 1 );
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

=item C<< model_as_stream >>

Returns an iterator object containing every statement in the model.

=cut

sub model_as_stream {
	my $self	= shift;
	my $stream	= $self->get_statements( map { RDF::Query::Node::Variable->new($_) } qw(s p o) );
	return $stream;
}

=item C<< variable_columns ( $var ) >>

Given a variable name, returns the set of column aliases that store the values
for the column (values for Literals, URIs, and Blank Nodes).

=cut

sub variable_columns {
	my $self	= shift;
	my $var		= shift;
	
	### ORDERING of these is important to enforce the correct sorting of results
	### based on the SPARQL spec. Bnodes < IRIs < Literals, but since NULLs sort
	### higher than other values, the list needs to be reversed.
	return map { "${var}_$_" } (qw(Value URI Name));
}

=item C<< add_variable_values_joins >>

Modifies the query by adding LEFT JOINs to the tables in the database that
contain the node values (for literals, resources, and blank nodes).

=cut

my @NODE_TYPE_TABLES	= (
						['Resources', 'ljr', 'URI'],
						['Literals', 'ljl', qw(Value Language Datatype)],
						['Bnodes', 'ljb', qw(Name)]
					);
sub add_variable_values_joins {
	my $self	= shift;
	my $context	= shift;
	my $varhash	= shift;
	my @vars	= keys %$varhash;
	my %select_vars	= map { $_ => 1 } @vars;
	my %variable_value_cols;
	
	my $vars	= $context->{vars};
	my $from	= $context->{from_tables};
	my $where	= $context->{where_clauses};
	
	my @cols;
	my $uniq_count	= 0;
	my (%seen_vars, %seen_joins);
	foreach my $var (grep { not $seen_vars{ $_ }++ } (@vars, keys %$vars)) {
		my $col	= $vars->{ $var };
		unless ($col) {
			throw RDF::Query::Error::CompilationError "*** Nothing is known about the variable ?${var}";
		}
		
		my $col_table	= (split(/[.]/, $col))[0];
		my ($count)		= ($col_table =~ /\w(\d+)/);
		
		warn "var: $var\t\tcol: $col\t\tcount: $count\t\tunique count: $uniq_count\n" if (DEBUG);
		
		push(@cols, "${col} AS ${var}_Node") if ($select_vars{ $var });
		foreach (@NODE_TYPE_TABLES) {
			my ($table, $alias, @join_cols)	= @$_;
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
			my ($alias)	= ($f =~ m/Statements\d* (\w\d+)/);	#split(/ /, $f))[1];
			
			if ($alias eq $col_table) {
#				my (@tables, @where);
				foreach (@NODE_TYPE_TABLES) {
					my ($vtable, $vname)	= @$_;
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
		
		$uniq_count++;
	}
	
	return (\%variable_value_cols, @cols);
}

sub _sql_for_pattern {
	my $self	= shift;
	my $pattern	= shift;
	my $ctx		= shift;
	my %args	= @_;
	my $type	= $pattern->type;
	my $method	= "_sql_for_" . lc($type);
	my $model	= $self->model_name;
	my $hash	= _mysql_hash( $model );
	my $context	= {
					next_alias		=> 0,
					level			=> 0,
					statement_table	=> "Statements${hash}",
				};
	if ($self->can($method)) {
		$self->$method( $pattern, $ctx, $context );
		return $self->_sql_from_context( $context, %args );
	} else {
		throw Error ( -text => "Don't know how to turn a $type into SQL" );
	}
}

use constant INDENT	=> "\t";
sub _sql_from_context {
	my $self	= shift;
	my $context	= shift;
	my %args	= @_;
	my $vars	= $context->{vars};
	my $from	= $context->{from_tables} || [];
	my $where	= $context->{where_clauses} || [];
	my $unique	= 0;	# XXX
	
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
	
#	my @cols	= map { _get_var( $context, $_ ) . " AS $_" } keys %$vars;
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
				push(@sort, map { "$_ $dir" } $self->variable_columns( $col ));
			}
		}
		if (@sort) {
			push(@sql, "ORDER BY " . join(', ', @sort));
		}
	}
#	push(@sql, $self->order_by_clause( $varcols, $level ) );
#	push(@sql, $self->limit_clause( $options ) );
	
	my $sql	= join("\n", grep {length} @sql);
	return $sql;
}

sub _get_level { return $_[0]{level}; }
sub _next_alias { return $_[0]{next_alias}++; }
sub _statements_table { return $_[0]{statement_table}; };
sub _add_from { push( @{ $_[0]{from_tables} }, $_[1] ); }
sub _add_where { push( @{ $_[0]{where_clauses} }, $_[1] ); }
sub _get_var { return $_[0]{vars}{ $_[1] }; }
sub _add_var { $_[0]{vars}{ $_[1] } = $_[2]; }

sub _sql_for_triple {
	my $self	= shift;
	my $triple	= shift;
	my $has_graph_name	= (scalar(@_) == 2);
	my $ctx		= shift;
	my $context	= shift;
	
	my @posmap		= qw(subject predicate object);
	my ($s,$p,$o)	= map { $triple->$_() } @posmap;
	my $table		= "s" . _next_alias($context);
	my $stable		= _statements_table($context);
	my $level		= _get_level( $context );
	_add_from( $context, "${stable} ${table}" );
	foreach my $method (@posmap) {
		my $node	= $triple->$method();
		my $pos		= $method;
		my $col		= "${table}.${pos}";
		next unless defined($node);
		$self->_add_sql_node_clause( $col, $node, $context );
	}
	if (defined($ctx)) {
		$self->_add_sql_node_clause( "${table}.Context", $ctx, $context );
	} else {
		$self->_add_sql_node_clause( "${table}.Context", RDF::Query::Node::Variable->new( 'sql_ctx_' . ++$self->{ context_variable_count } ), $context );
	}
}

sub _add_sql_node_clause {
	my $self	= shift;
	my $col		= shift;
	my $node	= shift;
	my $context	= shift;
	if ($node->isa('RDF::Query::Node::Variable')) {
		my $name	= $node->name;
		if (my $existing_col = _get_var( $context, $name )) {
			_add_where( $context, "$col = ${existing_col}" );
		} else {
			_add_var( $context, $name, $col );
		}
	} elsif ($node->isa('RDF::Query::Node::Resource')) {
		my $uri	= $node->uri_value;
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
	} elsif ($node->isa('RDF::Query::Node::Blank')) {
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
#		my $id	= $node->blank_identifier;
#		my $b	= "b$level";
#		_add_from( $context, "Bnodes $b" );
#		_add_where( $context, "${col} = ${b}.ID" );
#		_add_where( $context, "${b}.Name = '$id'" );
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		my $id	= $self->_mysql_node_hash( $node );
		$id		=~ s/\D//;
		_add_where( $context, "${col} = $id" );
	} else {
		throw RDF::Query::Error::CompilationError( -text => "Unknown node type: " . Dumper($node) );
	}
}


sub _sql_for_bgp {
	my $self	= shift;
	my $bgp		= shift;
	my $ctx		= shift;
	my $context	= shift;
	
	foreach my $triple ($bgp->triples) {
		$self->_sql_for_triple( $triple, $ctx, $context );
	}
}



=item C<< _mysql_hash ( $data ) >>

Returns a hash value for the supplied C<$data> string. This value is computed
using the same algorithm that Redland's mysql storage backend uses.

=cut

sub _mysql_hash {
	my $data	= shift;
	my @data	= unpack('C*', md5( $data ));
	my $sum		= Math::BigInt->new('0');
#	my $count	= 0;
	foreach my $count (0 .. 7) {
#	while (@data) {
		my $data	= Math::BigInt->new( $data[ $count ] ); #shift(@data);
		my $part	= $data << (8 * $count);
#		warn "+ $part\n";
		$sum		+= $part;
	} # continue { last if ++$count == 8 }	# limit to 64 bits
#	warn "= $sum\n";
	$sum	=~ s/\D//;	# get rid of the extraneous '+' that pops up under perl 5.6
	return $sum;
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
	
	my $data;
	if ($node->isa('RDF::Query::Node::Resource')) {
		my $value	= $node->uri_value;
		$data	= 'R' . $value;
	} elsif ($node->isa('RDF::Query::Node::Blank')) {
		my $value	= $node->blank_identifier;
		$data	= 'B' . $value;
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		my $value	= $node->literal_value || '';
		my $lang	= $node->literal_value_language || '';
		my $dt		= $node->literal_datatype || '';
		no warnings 'uninitialized';
		$data	= sprintf("L%s<%s>%s", $value, $lang, $dt);
#		warn "($data)";
	} else {
		return undef;
	}
	
	my $hash	= _mysql_hash( $data );
	return $hash;
}

=item C<< model_name >>

Returns the name of the underlying model.

=cut

sub model_name {
	my $self	= shift;
	Carp::confess unless (blessed($self));
	return $self->{model_name};
}

=item C<< dbh >>

Returns the underlying DBI database handle.

=cut

sub dbh {
	my $self	= shift;
	my $dbh		= $self->{dbh};
	return $dbh;
}

=item C<< init >>

Creates the necessary tables in the underlying database.

=cut

sub init {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $name	= $self->model_name;
	my $id		= _mysql_hash( $name );
	
	$dbh->begin_work;
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Literals (
            ID bigint unsigned PRIMARY KEY,
            Value longtext NOT NULL,
            Language text NOT NULL DEFAULT "",
            Datatype text NOT NULL DEFAULT ""
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Resources (
            ID bigint unsigned PRIMARY KEY,
            URI text NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Bnodes (
            ID bigint unsigned PRIMARY KEY,
            Name text NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Models (
            ID bigint unsigned PRIMARY KEY,
            Name text NOT NULL
        );
END
    
    $dbh->do( "DROP TABLE IF EXISTS Statements${id}" ) || do { $dbh->rollback; return undef };
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE Statements${id} (
            Subject bigint unsigned NOT NULL,
            Predicate bigint unsigned NOT NULL,
            Object bigint unsigned NOT NULL,
            Context bigint unsigned NOT NULL DEFAULT 0,
            UNIQUE (Subject, Predicate, Object, Context)
        );
END

	$dbh->do( "DELETE FROM Models WHERE ID = ${id}") || do { $dbh->rollback; return undef };
	$dbh->do( "INSERT INTO Models (ID, Name) VALUES (${id}, ?)", undef, $name ) || do { $dbh->rollback; return undef };
	
	$dbh->commit;
	warn "committed" if (DEBUG);
}

sub _cleanup {
	my $self	= shift;
	if ($self->{dbh}) {
		my $dbh		= $self->{dbh};
		my $name	= $self->{model_name};
		my $id		= _mysql_hash( $name );
		if ($self->{ remove_store }) {
			$dbh->do( "DROP TABLE IF EXISTS `Statements${id}`;" );
			$dbh->do( "DELETE FROM Models WHERE Name = ?", undef, $name );
		}
	}
}

sub DESTROY {
	my $self	= shift;
	$self->_cleanup;
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


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

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
