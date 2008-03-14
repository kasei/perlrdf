=head1 NAME

RDF::Trine::Store::DBI - [One line description of module's purpose here]


=head1 VERSION

This document describes RDF::Trine::Store::DBI version 0.002


=head1 SYNOPSIS

    use RDF::Trine::Store::DBI;

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

package RDF::Trine::Store::DBI;

use strict;
use warnings;
no warnings 'redefine';

use DBI;
use Carp;
use Error;
use DBI;
use File::Temp;
use Scalar::Util qw(blessed reftype refaddr);
use Digest::MD5 ('md5');
use Math::BigInt;
use Data::Dumper;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Statement::Quad;
use RDF::Trine::Iterator;

use RDF::Trine::Store::DBI::mysql;

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
		if ($dsn =~ /^DBI:mysql:/) {
			$class	= 'RDF::Trine::Store::DBI::mysql';
		}
		warn "Connecting to $dsn ($user, $pass)" if (DEBUG);
		$dbh		= DBI->connect( $dsn, $user, $pass );
	}
	
	my $self	= bless( {
		model_name				=> $name,
		dbh						=> $dbh,
		statements_table_prefix	=> 'Statements',
		%args
	}, $class );
	
	return $self;
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
	my $triple	= RDF::Trine::Statement->new( $subj, $pred, $obj );
	my @vars	= $triple->referenced_variables;
	
	local($self->{context_variable_count})	= 0;
	my $sql		= $self->_sql_for_pattern( $triple, $context, @_ );
#	warn $sql;
	my $sth		= $dbh->prepare( $sql );
	$sth->execute();
	
	my $sub		= sub {
		my $row	= $sth->fetchrow_hashref;
		return undef unless (defined $row);
		my @triple;
		my $temp_var_count	= 1;
		foreach my $node ($triple->nodes) {
			if ($node->is_variable) {
				my $name	= $node->name;
				my $prefix	= $name . '_';
				if (defined $row->{ "${prefix}URI" }) {
					push( @triple, RDF::Trine::Node::Resource->new( $row->{"${prefix}URI" } ) );
				} elsif (defined $row->{ "${prefix}Name" }) {
					push( @triple, RDF::Trine::Node::Blank->new( $row->{"${prefix}Name" } ) );
				} else {
					push( @triple, RDF::Trine::Node::Literal->new( @{ $row }{map {"${prefix}$_"} qw(Value Language Datatype) } ) );
				}
			} else {
				push(@triple, $node);
			}
		}
		if (blessed($context) and $context->is_variable) {
			my $prefix	= 'sql_ctx_1__';
			if (defined $row->{ "${prefix}URI" }) {
				push( @triple, RDF::Trine::Node::Resource->new( $row->{"${prefix}URI" } ) );
			} elsif (defined $row->{ "${prefix}Name" }) {
				push( @triple, RDF::Trine::Node::Blank->new( $row->{"${prefix}Name" } ) );
			} elsif (defined $row->{ "${prefix}Value" }) {
				push( @triple, RDF::Trine::Node::Literal->new( @{ $row }{map {"${prefix}$_"} qw(Value Language Datatype) } ) );
			}
		} elsif ($context) {
			push( @triple, $context );
		}
		
		my $triple	= (@triple == 3)
					? RDF::Trine::Statement->new( @triple )
					: RDF::Trine::Statement::Quad->new( @triple );
		return $triple;
	};
	
	return RDF::Trine::Iterator::Graph->new( $sub )
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
				$bindings{ $name }	 = RDF::Trine::Node::Resource->new( $row->{"${prefix}URI" } );
			} elsif (defined $row->{ "${prefix}Name" }) {
				$bindings{ $name }	 = RDF::Trine::Node::Blank->new( $row->{"${prefix}Name" } );
			} elsif (defined $row->{ "${prefix}Value" }) {
				$bindings{ $name }	 = RDF::Trine::Node::Literal->new( @{ $row }{map {"${prefix}$_"} qw(Value Language Datatype) } );
			} else {
				$bindings{ $name }	= undef;
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
	return RDF::Trine::Iterator::Bindings->new( $sub, \@vars, @args )
}


=item C<< get_contexts >>


=cut

sub get_contexts {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my $stable	= $self->statements_table;
 	my $sql		= "SELECT DISTINCT Context, r.URI AS URI, b.Name AS Name, l.Value AS Value, l.Language AS Language, l.Datatype AS Datatype FROM ${stable} s LEFT JOIN Resources r ON (r.ID = s.Context) LEFT JOIN Literals l ON (l.ID = s.Context) LEFT JOIN Bnodes b ON (b.ID = s.Context) WHERE Context != 0 ORDER BY URI, Name, Value;";
 	my $sth		= $dbh->prepare( $sql );
 	$sth->execute();
 	my $sub		= sub {
 		my $row	= $sth->fetchrow_hashref;
 		if ($row->{URI}) {
 			return RDF::Trine::Node::Resource->new( $row->{URI} );
 		} elsif ($row->{Name}) {
 			return RDF::Trine::Node::Blank->new( $row->{Name} );
 		} elsif (defined $row->{Value}) {
 			return RDF::Trine::Node::Literal->new( @{ $row }{qw(Value Language Datatype)} );
 		} else {
 			return;
 		}
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
	Carp::confess;
	my $dbh		= $self->dbh;
# 	Carp::confess unless (blessed($stmt));
	my $stable	= $self->statements_table;
	my @nodes	= $stmt->nodes;
	foreach my $n (@nodes) {
		$self->_add_node( $n );
	}
	
	my @values	= map { $self->_mysql_node_hash( $_ ) } @nodes;
	if ($stmt->isa('RDF::Trine::Statement::Quad')) {
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
	my $sql	= "SELECT 1 FROM ${stable} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?";
	my $sth	= $dbh->prepare( $sql );
	$sth->execute( @values );
	unless ($sth->fetch) {
		my $sql		= sprintf( "INSERT INTO ${stable} (Subject, Predicate, Object, Context) VALUES (%s,%s,%s,%s)", @values );
		my $sth		= $dbh->prepare( $sql );
		$sth->execute();
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
	my @nodes	= $stmt->nodes;
	my $sth		= $dbh->prepare("DELETE FROM ${stable} WHERE Subject = ? AND Predicate = ? AND Object = ? AND Context = ?");
	my @values	= map { $self->_mysql_node_hash( $_ ) } (@nodes, $context);
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
	my $sth		= $dbh->prepare("DELETE FROM ${stable} WHERE ${where}");
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
# 	Carp::confess unless (blessed($node));
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

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
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
	my $triple	= RDF::Trine::Statement->new( map { defined($_) ? $_ : RDF::Trine::Node::Variable->new( 'n' . $var++ ) } ($subj, $pred, $obj) );
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
	foreach my $var (grep { not $seen_vars{ $_ }++ } (@vars, keys %$vars)) {
		my $col	= $vars->{ $var };
		unless ($col) {
			throw RDF::Trine::Error::CompilationError -text => "*** Nothing is known about the variable ?${var}";
		}
		
		my $col_table	= (split(/[.]/, $col))[0];
		my ($count)		= ($col_table =~ /\w(\d+)/);
		
		warn "var: $var\t\tcol: $col\t\tcount: $count\t\tunique count: $uniq_count\n" if (DEBUG);
		
		push(@cols, "${col} AS ${var}_Node") if ($select_vars{ $var });
		foreach my $type (reverse sort keys %NODE_TYPE_TABLES) {
			next if ($context->{restrict}{$var}{$type});
			my ($table, $alias, @join_cols)	= @{ $NODE_TYPE_TABLES{ $type } };
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
		
		$uniq_count++;
	}
	
	return (\%variable_value_cols, @cols);
}

sub _sql_for_pattern {
	my $self		= shift;
	my $pattern		= shift;
	my $ctx_node	= shift;
	my %args		= @_;
	my $type		= $pattern->type;
	my $method		= "_sql_for_" . lc($type);
	my $context		= {
						next_alias		=> 0,
						level			=> 0,
						statement_table	=> $self->statements_table,
					};
	
	if ($self->can($method)) {
		$self->$method( $pattern, $ctx_node, $context );
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
	
	my $expr	= $filter->expr;
	my $pattern	= $filter->pattern;
	my $type		= $pattern->type;
	my $method		= "_sql_for_" . lc($type);
	$self->$method( $pattern, $ctx_node, $context );
	$self->_sql_for_expr( $expr, $ctx_node, $context );
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
		} else {
			throw RDF::Trine::Error::CompilationError -text => "Unknown function data: " . Dumper($expr);
		}
	} else {
		throw RDF::Trine::Error::CompilationError -text => "Unknown expr data: " . Dumper($expr);
	}
	return;
}

{
	my %restrictions	= (
		subject		=> ['literal'],
		predicate	=> [qw(literal blank)],
		object		=> [],
		context		=> [],
	);
sub _sql_for_triple {
	my $self	= shift;
	my $triple	= shift;
	my $has_graph_name	= (scalar(@_) == 2);
	my $ctx		= shift;
	my $context	= shift;
	
	my $quad		= $triple->isa('RDF::Trine::Statement::Quad');
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
		} else {
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
		$self->_sql_for_triple( $triple, $ctx, $context );
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
		$self->$method( $p, $ctx, $context );
	}
}



=item C<< _mysql_hash ( $data ) >>

Returns a hash value for the supplied C<$data> string. This value is computed
using the same algorithm that Redland's mysql storage backend uses.

=cut

sub _mysql_hash;
sub _mysql_hash_pp {
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

BEGIN {
	eval "use RDF::Trine::XS;";
	no strict 'refs';
	*{ '_mysql_hash' }	= (RDF::Trine::XS->can('hash'))
		? \&RDF::Trine::XS::hash
		: \&_mysql_hash_pp;
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
	if ($node->isa('RDF::Trine::Node::Resource')) {
		my $value	= $node->uri_value;
		$data	= 'R' . $value;
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		my $value	= $node->blank_identifier;
		$data	= 'B' . $value;
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $value	= $node->literal_value || '';
		my $lang	= $node->literal_value_language || '';
		my $dt		= $node->literal_datatype || '';
		no warnings 'uninitialized';
		$data	= sprintf("L%s<%s>%s", $value, $lang, $dt);
#		warn "($data)";
	} else {
		return undef;
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
	warn $sql;
	
	my $dbh			= $self->dbh;
	$dbh->do( $sql );
	
	return $stable;
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
