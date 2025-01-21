# RDF::Query::Compiler::SQL
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Compiler::SQL - Compile a SPARQL query directly to SQL.

=head1 VERSION

This document describes RDF::Query::Compiler::SQL version 2.910.

=head1 STATUS

This module's API and functionality should be considered deprecated.
If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=cut

package RDF::Query::Compiler::SQL;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Query::Error qw(:try);

use Log::Log4perl;
use List::Util qw(first);
use Data::Dumper;
use Math::BigInt;
use Digest::MD5 ('md5');
#use Digest::Perl::MD5 (); #('md5');
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);

use RDF::Query::Error qw(:try);

######################################################################

my (@NODE_TYPE_TABLES, %NODE_TYPE_TABLES);
our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
	@NODE_TYPE_TABLES	= (
							['Resources', 'ljr', 'URI'],
							['Literals', 'ljl', qw(Value Language Datatype)],
							['Bnodes', 'ljb', qw(Name)]
						);
	%NODE_TYPE_TABLES	= map { $_->[0] => [ @{ $_ }[1 .. $#{ $_ }] ] } @NODE_TYPE_TABLES;
}

######################################################################

use constant INDENT		=> "\t";

=head1 METHODS

=over 4

=cut

=item C<< new ( $parse_tree ) >>

Returns a new compiler object.

=cut

sub new {
	my $class	= shift;
	my $parsed	= shift;
	my $model	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.compiler.sql");
	my $stable;
	if ($model) {
		my $mhash	= _mysql_hash( $model );
		$l->debug("Model: $model => $mhash\n");
		$stable		= "Statements${mhash}";
	} else {
		$stable		= 'Statements';
	}
	
	my $self	= bless( {
					parsed	=> $parsed,
					stable	=> $stable,
					vars	=> {},
					from	=> [],
					where	=> [],
				}, $class );
				
	return $self;
}


=item C<< compile () >>

Returns a SQL query string for the specified parse tree.

=cut

sub compile {
	my $self	= shift;
	my $parsed	= $self->{parsed};
	
	my $sql;
	try {
		my $method	= uc $parsed->{'method'};
		if ($method eq 'SELECT') {
			$sql	= $self->emit_select();
		} else {
			throw RDF::Query::Error::CompilationError( -text => "SQL compilation of $method queries not yet implemented." );
		}
	} catch RDF::Query::Error::CompilationError with {
		my $err	= shift;
		throw $err;
	};
	
	return $sql;
}


=item C<< emit_select >>

Returns a SQL query string representing the query.

=cut

sub emit_select {
	my $self	= shift;
	my $parsed	= $self->{parsed};
	
	my $level		= \do { my $a = 0 };
	my @vars		= map { $_->name } @{ $parsed->{variables} };
	my %select_vars	= map { $_ => 1 } @vars;
	
	$self->patterns2sql( $parsed->{'triples'}, $level );
	
	my ($varcols, @cols)	= $self->add_variable_values_joins;
	my $vars	= $self->{vars};
	my $from	= $self->{from};
	my $where	= $self->{where};
	
	my $options				= $self->{options} || {};
	my $unique				= $options->{'distinct'};
	
	my $from_clause;
	foreach my $f (@$from) {
		$from_clause	.= ",\n" . INDENT if ($from_clause and $from_clause =~ m/[^(]$/ and $f !~ m/^([)]|LEFT JOIN)/);
		$from_clause	.= $f;
	}
	
	
	my $where_clause	= @$where ? "WHERE\n"
						. INDENT . join(" AND\n" . INDENT, @$where) : '';
	
	
	my @sql	= (
				"SELECT" . ($unique ? ' DISTINCT' : ''),
				INDENT . join(",\n" . INDENT, @cols),
				"FROM",
				INDENT . $from_clause,
				$where_clause,
			);
	
	push(@sql, $self->order_by_clause( $varcols, $level ) );
	push(@sql, $self->limit_clause( $options ) );
	
	my $sql	= join("\n", grep {length} @sql);
	return $sql;
}

=item C<< limit_clause >>

Returns a SQL LIMIT clause, or an empty string if the query does not need limiting.

=cut

sub limit_clause {
	my $self	= shift;
	my $options	= shift;
	if (my $limit = $options->{limit}) {
		return "LIMIT ${limit}";
	} else {
		return "";
	}
}

=item C<< order_by_clause >>

Returns a SQL ORDER BY clause, or an empty string if the query does not use ordering.

=cut

sub order_by_clause {
	my $self	= shift;
	my $varcols	= shift;
	my $level	= shift || \do{ my $a = 0 };
	
	my $vars	= $self->{vars};
	
	my $options				= $self->{options} || {};
	my %variable_value_cols	= %$varcols;
	
	my $sql		= '';
	if ($options->{orderby}) {
		my $data	= $options->{orderby}[0];
		my ($dir, @operands)	= @$data;
		
		if (scalar(@operands) > 1) {
			throw RDF::Query::Error::CompilationError( -text => "Can't sort by more than one column yet." );
		}
		
		my $sort	= $operands[0];
		if (blessed($sort) and $sort->type eq 'VAR') {
			my $var		= $sort->name;
			my @cols	= $self->variable_columns( $var );
			$sql	.= "ORDER BY\n"
					. INDENT . join(', ', map { "$_ $dir" } @cols );
		} elsif (blessed($sort) and $sort->type eq 'FUNCTION') {
			my $uri		= $self->qualify_uri( $sort->uri );
			my $col		= $self->expr2sql( $sort, $level );
			my @sort;
			foreach my $var (keys %$vars) {
				my ($l_sort_col, $r_sort_col, $b_sort_col)	= @{ $variable_value_cols{ $var } };
				my $varcol	= $vars->{ $var };
				if ($col =~ /${varcol}/) {
					my ($l, $r, $b)	= ($col) x 3;
					$l		=~ s/$varcol/${l_sort_col}/;
					$r		=~ s/$varcol/${r_sort_col}/;
					$b		=~ s/$varcol/${b_sort_col}/;
					push(@sort, "$l $dir, $r $dir, $b $dir");
					last;
				}
			}
			unless (@sort) {
				push(@sort, "${col} $dir");
			}
			$sql	.= "ORDER BY\n"
					. INDENT . join(', ', @sort);
		} else {
			throw RDF::Query::Error::CompilationError( -text => "Can't sort by $$data[1][0] yet." );
		}
	}
	
	return $sql;
}

=item C<< variable_columns ( $var ) >>

Given a variable name, returns the set of column aliases that store the values
for the column (values for Literals, URIs, and Blank Nodes).

=cut

sub variable_columns {
	my $self	= shift;
	my $var		= shift;
	return map { "${var}_$_" } (qw(Value URI Name));
}

=item C<< add_variable_values_joins >>

Modifies the query by adding LEFT JOINs to the tables in the database that
contain the node values (for literals, resources, and blank nodes).

=cut

sub add_variable_values_joins {
	my $self	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.algebra.service");
	my $parsed	= $self->{parsed};
	my @vars	= map { $_->name } @{ $parsed->{variables} };
	my %select_vars	= map { $_ => 1 } @vars;
	my %variable_value_cols;
	
	my $vars	= $self->{vars};
	my $from	= $self->{from};
	my $where	= $self->{where};
	
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
		
		$l->debug("var: $var\t\tcol: $col\t\tcount: $count\t\tunique count: $uniq_count\n");
		
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

=item C<< patterns2sql ( \@triples, \$level, %args ) >>

Builds the SQL query in instance data from the supplied C<@triples>.
C<$level> is used as a unique identifier for recursive calls.

C<%args> may contain callback closures for the following keys:

  'where_hook'
  'from_hook'

When present, these closures are used to add SQL FROM and WHERE clauses
to the query instead of adding them directly to the object's instance data.

=cut

sub patterns2sql {
	my $self	= shift;
	my $triples	= shift;
	my $level	= shift || \do{ my $a = 0 };
	my %args	= @_;
	
#	my %vars	= scalar(@_) ? %{ $_[0] } : ();
	
	my $parsed		= $self->{parsed};
	my $parsed_vars	= $parsed->{variables};
	my %queryvars	= map { $_->name => 1 } @$parsed_vars;
	
#	my (@from, @where);
	
	my $from	= $self->{from};
	my $where	= $self->{where};
	my $vars	= $self->{vars};

	my $add_where	= sub {
		my $w	= shift;
		if (my $hook = $args{ where_hook }) {
			push(@$where, $hook->( $w ));
		} else {
			push(@$where, $w);
		}
		return $w;
	};
	
	my $add_from	= sub {
		my $f	= shift;
		if (my $hook = $args{ from_hook }) {
			push(@$from, $hook->( $f ));
		} else {
			push(@$from, $f);
		}
		return $f;
	};
	
	
	my $triple	= shift(@$triples);
	Carp::confess "unblessed atom: " . Dumper($triple) unless (blessed($triple));
	
	if ($triple->isa('RDF::Query::Algebra::Triple') or $triple->isa('RDF::Query::Algebra::Quad')) {
		my $quad	= $triple->isa('RDF::Query::Algebra::Quad');
		my @posmap	= ($quad)
					? qw(subject predicate object context)
					: qw(subject predicate object);
#		$add_from->('(');
		my $table	= "s${$level}";
		my $stable	= $self->{stable};
		$add_from->( "${stable} ${table}" );
		foreach my $method (@posmap) {
			my $node	= $triple->$method();
			my $pos		= $method;
			my $col		= "${table}.${pos}";
			if ($node->isa('RDF::Query::Node::Variable')) {
				my $name	= $node->name;
				if (exists $vars->{ $name }) {
					my $existing_col	= $vars->{ $name };
					$add_where->( "$col = ${existing_col}" );
				} else {
					$vars->{ $name }	= $col;
				}
			} elsif ($node->isa('RDF::Query::Node::Resource')) {
				my $uri	= $node->uri_value;
				my $id	= $self->_mysql_node_hash( $node );
				$id		=~ s/\D//;
				$add_where->( "${col} = $id" );
			} elsif ($node->isa('RDF::Query::Node::Blank')) {
				my $id	= $node->blank_identifier;
				my $b	= "b${$level}";
				$add_from->( "Bnodes $b" );
				
				$add_where->( "${col} = ${b}.ID" );
				$add_where->( "${b}.Name = '$id'" );
			} elsif ($node->isa('RDF::Query::Node::Literal')) {
				my $id	= $self->_mysql_node_hash( $node );
				$id		=~ s/\D//;
				$add_where->( "${col} = $id" );
			} else {
				throw RDF::Query::Error::CompilationError( -text => "Unknown node type: " . Dumper($node) );
			}
		}
#		$add_from->(')');
	} else {
		if ($triple->isa('RDF::Query::Algebra::Optional')) {
			throw RDF::Query::Error::CompilationError( -text => "SQL compilation of OPTIONAL blocks is currently broken" );
		} elsif ($triple->isa('RDF::Query::Algebra::NamedGraph')) {
			$self->patterns2sql( [ $triple->pattern ], $level, %args );
# 			my $graph	= $triple->graph;
# 			my $pattern	= $triple->pattern;
# 			if ($graph->isa('RDF::Query::Node::Variable')) {
# 				my $name	= $graph->name;
# 				my $context;
# 				my $hook	= sub {
# 								my $f	= shift;
# 								if ($f =~ /^Statements/i) {
# 									my $alias	= (split(/ /, $f))[1];
# 									if (defined($context)) {
# 										$context	=~ s/\D//;
# 										$add_where->( "${alias}.Context = ${context}" );
# 									} else {
# 										$context	= "${alias}.Context";
# 										$vars->{ $name }	= $context;
# 									}
# 								}
# 								return $f;
# 							};
# 				$self->patterns2sql( [ $pattern ], $level, from_hook => $hook );
# 			} else {
# 				my $hash	= $self->_mysql_node_hash( $graph );
# 				my $hook	= sub {
# 								my $f	= shift;
# 								if ($f =~ /^Statements/i) {
# 									my $alias	= (split(/ /, $f))[1];
# 									$hash	=~ s/\D//;
# 									$add_where->( "${alias}.Context = ${hash}" );
# 								}
# 								return $f;
# 							};
# 				$self->patterns2sql( [ $pattern ], $level, from_hook => $hook );
# 			}
		} elsif ($triple->isa('RDF::Query::Algebra::Filter')) {
			++$$level;
			my $expr		= $triple->expr;
			my $pattern	= $triple->pattern;
			$self->expr2sql( $expr, $level, from_hook => $add_from, where_hook => $add_where );
			++$$level;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::BasicGraphPattern')) {
			++$$level;
			$self->patterns2sql( [ $triple->triples ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::GroupGraphPattern')) {
			++$$level;
			$self->patterns2sql( [ $triple->patterns ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::Distinct')) {
			$self->{options}{distinct}	= 1;
			my $pattern	= $triple->pattern;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::Limit')) {
			$self->{options}{limit}	= $triple->limit;
			my $pattern	= $triple->pattern;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::Offset')) {
			$self->{options}{offset}	= $triple->offset;
			my $pattern	= $triple->pattern;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::Sort')) {
			$self->{options}{orderby}	= [ $triple->orderby ];
			my $pattern	= $triple->pattern;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} elsif ($triple->isa('RDF::Query::Algebra::Project')) {
			my $pattern	= $triple->pattern;
			$self->patterns2sql( [ $pattern ], $level, %args );
		} else {
			throw RDF::Query::Error::CompilationError( -text => "Unknown pattern type '$triple' in SQL compilation." );
		}
	}
	
	if (scalar(@$triples)) {
		++$$level;
		$self->patterns2sql( $triples, $level );
	}
	return;
#	return (\%vars, \@from, \@where);
}

=item C<< expr2sql ( $expression, \$level, %args ) >>

Returns a SQL expression for the supplied query C<$expression>.
C<$level> is used as a unique identifier for recursive calls.

C<%args> may contain callback closures for the following keys:

  'where_hook'
  'from_hook'

When present, these closures are used to add necessary SQL FROM and WHERE
clauses to the query.

=cut

sub expr2sql {
	my $self	= shift;
	my $expr	= shift;
	my $level	= shift || \do{ my $a = 0 };
	my %args	= @_;
	
	
	my $equality	= do { no warnings 'uninitialized'; ($args{'equality'} eq 'rdf') ? 'rdf' : 'xpath' };
	
	my $from	= $self->{from};
	my $where	= $self->{where};
	my $vars	= $self->{vars};
	
	my $sql;
	my $add_where	= sub {
		my $w	= shift;
		$sql	||= $w;
		if (my $hook = $args{ where_hook }) {
			$hook->( $w );
		}
	};
	
	my $add_from	= sub {
		my $f	= shift;
		if (my $hook = $args{ from_hook }) {
			$hook->( $f );
		}
	};
	
	my $parsed		= $self->{parsed};
	my $parsed_vars	= $parsed->{variables};
	my %queryvars	= map { $_->name => 1 } @$parsed_vars;
	
	Carp::confess unless ref($expr);
	
	my $blessed	= blessed($expr);
	if ($blessed and $expr->isa('RDF::Query::Node')) {
		if ($expr->isa('RDF::Query::Node::Literal')) {
			my $literal	= $expr->literal_value;
			my $dt		= $expr->literal_datatype;
			
			my $hash	= $self->_mysql_node_hash( $expr );
			
			if ($equality eq 'rdf') {
				$literal	= $hash;
			} else {
				if (defined($dt)) {
					my $uri		= $dt;
					my $func	= $self->get_function( $self->qualify_uri( $uri ) );
					if ($func) {
						my ($v, $f, $w)	= $func->( $self, $parsed_vars, $level, RDF::Query::Node::Literal->new($literal) );
						$literal	= $w->[0];
					} else {
						$literal	= qq("${literal}");
					}
				} else {
					$literal	= qq('${literal}');
				}
			}
			
			$add_where->( $literal );
		} elsif ($expr->isa('RDF::Query::Node::Blank')) {
			my $hash		= $self->_mysql_node_hash( $expr );
			$add_where->( $hash );
		} elsif ($expr->isa('RDF::Query::Node::Resource')) {
			my $uri		= $self->_mysql_node_hash( $expr );
			$add_where->( $uri );
		} elsif ($expr->isa('RDF::Query::Node::Variable')) {
			my $name	= $expr->name;
			my $col		= $vars->{ $name };
			no warnings 'uninitialized';
			$add_where->( qq(${col}) );
		}
	} elsif ($blessed and $expr->isa('RDF::Query::Expression::Function')) {
		my $uri	= $expr->uri->uri_value;
		my $func	= $self->get_function( $uri );
		if ($func) {
			my ($v, $f, $w)	= $func->( $self, $parsed_vars, $level, $expr->arguments );
			foreach my $key (keys %$v) {
				my $val	= $v->{ $key };
				$vars->{ $key }	= $val unless (exists($vars->{ $key }));
			}
			
			foreach my $f (@$f) {
				$add_from->( @$f );
			}
			
			foreach my $w (@$w) {
				$add_where->( $w );
			}
		} else {
			throw RDF::Query::Error::CompilationError( -text => "Unknown custom function $uri in FILTER." );
		}
	} elsif ($blessed and $expr->isa('RDF::Query::Expression')) {
		my $op		= $expr->op;
		my @args	= $expr->operands;
		
		if ($op eq '!') {
			if ($args[0]->isa('RDF::Query::Expression::Function')) {
				if ($args[0]->uri->uri_value eq 'sparql:isbound') {
					my $expr	= RDF::Query::Expression::Function->new(
									RDF::Query::Node::Resource->new('rdfquery:isNotBound'),
									$args[0]->arguments
								);
					$self->expr2sql( $expr, $level, %args );
				}
			}
		} else {
			if ($op =~ m#^(=|==|!=|[<>]=?|[*]|/|[-+])$#) {
				
				$op	= '<>' if ($op eq '!=');
				$op	= '=' if ($op eq '==');
				
				my ($a, $b)	= @args;
				my $a_type	= $a->type;
				my $b_type	= $b->type;
				
				try {
					if ($op eq '=') {
						if ($a_type eq 'VAR' and $b_type eq 'VAR') {
							# comparing equality on two type-unknown variables.
							# could need rdf-term equality, so punt to the
							# catch block below.
							throw RDF::Query::Error::ComparisonError;
						}
					}
					
					foreach my $data ([$a_type, 'LHS'], [$b_type, 'RHS']) {
						my ($type, $side)	= @$data;
						unless ($type =~ m/^(VAR|LITERAL|FUNCTION)$/) {
							if ($op =~ m/^!?=$/) {
								# throw to the catch block below.
								throw RDF::Query::Error::ComparisonError( -text => "Using comparison operator '${op}' on unknown node type requires RDF-Term semantics." );
							} else {
								# throw error out of the compiler.
								throw RDF::Query::Error::CompilationError( -text => "Cannot use the comparison operator '${op}' on a ${side} ${type} node." );
							}
						}
					}
					
					if ($a_type eq 'VAR') {
						++$$level; my $var_name_a	= $self->expr2sql( $a, $level, equality => $equality );
						my $sql_a	= "(SELECT value FROM Literals WHERE ${var_name_a} = ID LIMIT 1)";
						if ($b_type eq 'VAR') {
							# ?var cmp ?var
							++$$level; my $var_name_b	= $self->expr2sql( $b, $level, equality => $equality );
							my $sql_b	= "(SELECT value FROM Literals WHERE ${var_name_b} = ID LIMIT 1)";
							$add_where->( "${sql_a} ${op} ${sql_b}" );
						} else {
							# ?var cmp NODE
							++$$level; my $sql_b	= $self->expr2sql( $b, $level, equality => $equality );
							$add_where->( "${sql_a} ${op} ${sql_b}" );
						}
					} else {
						++$$level; my $sql_a	= $self->expr2sql( $a, $level, equality => $equality );
						if ($b->[0] eq 'VAR') {
							# ?var cmp NODE
							++$$level; my $var_name	= $self->expr2sql( $b, $level, equality => $equality );
							my $sql_b	= "(SELECT value FROM Literals WHERE ${var_name} = ID LIMIT 1)";
							$add_where->( "${sql_a} ${op} ${sql_b}" );
						} else {
							# NODE cmp NODE
							++$$level; my $sql_b	= $self->expr2sql( $b, $level, equality => $equality );
							$add_where->( "${sql_a} ${op} ${sql_b}" );
						}
					}
				} catch RDF::Query::Error::ComparisonError with {
					# we can't compare these terms using the XPath semantics (for literals),
					# so fall back on RDF-Term semantics.
					my $err	= shift;
					
					my @w;
					my $where_hook	= sub {
									my $w	= shift;
									push(@w, $w);
									return;
								};
					
					foreach my $expr (@args) {
						$self->expr2sql( $expr, $level, %args, %args, equality => 'rdf', where_hook => $where_hook )
					}
					
					$add_where->("$w[0] ${op} $w[1]");
					
				};
			} elsif ($op eq '&&') {
				foreach my $expr (@args) {
					$self->expr2sql( $expr, $level, %args )
				}
			} elsif ($op eq '||') {
				my @w;
				my $where_hook	= sub {
								my $w	= shift;
								push(@w, $w);
								return;
							};
				
				foreach my $expr (@args) {
					$self->expr2sql( $expr, $level, %args, where_hook => $where_hook )
				}
				
				my $where	= '(' . join(' OR ', map { qq<($_)> } @w) . ')';
				$add_where->( $where );
			} else {
				throw RDF::Query::Error::CompilationError( -text => "SQL compilation of FILTER($op) queries not yet implemented." );
			}
		}
	}
	return $sql;
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
	
	my $data;
	Carp::confess 'node a blessed node: ' . Dumper($node) unless blessed($node);
	if ($node->isa('RDF::Query::Node::Resource')) {
		my $value	= $node->uri_value;
		if (ref($value)) {
			$value	= $self->qualify_uri( $value );
		}
		$data	= 'R' . $value;
	} elsif ($node->isa('RDF::Query::Node::Blank')) {
		my $value	= $node->blank_identifier;
		$data	= 'B' . $value;
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		my $value	= $node->literal_value;
		my $lang	= $node->literal_value_language;
		my $dt		= $node->literal_datatype;
		no warnings 'uninitialized';
		$data	= sprintf("L%s<%s>%s", $value, $lang, $dt);
#		warn "($data)";
	} else {
		return undef;
	}
	
	my $hash	= _mysql_hash( $data );
	return $hash;
}

=item C<< qualify_uri ( $uri ) >>

Returns a fully qualified URI from the supplied C<$uri>. C<$uri> may already
be a qualified URI, or a parse tree for a qualified URI or QName. If C<$uri> is
a QName, the namespaces defined in the query parse tree are used to fully qualify.

=cut

sub qualify_uri {
	my $self	= shift;
	my $uri		= shift;
	my $parsed	= $self->{parsed};
	if (ref($uri) and $uri->[0] eq 'URI') {
		$uri	= $uri->[1];
	}
	
	if (ref($uri)) {
		my ($abbr, $local)	= @$uri;
		if (exists $parsed->{namespaces}{$abbr}) {
			my $ns		= $parsed->{namespaces}{$abbr};
			$uri		= join('', $ns, $local);
		} else {
			throw RDF::Query::Error::ParseError ( -text => "Unknown namespace prefix: $abbr" );
		}
	}
	return $uri;
}

=item C<add_function ( $uri, $function )>

Associates the custom function C<$function> (a CODE reference) with the
specified URI, allowing the function to be called by query FILTERs.

=cut

sub add_function {
	my $self	= shift;
	my $uri		= shift;
	my $code	= shift;
	if (ref($self)) {
		$self->{'functions'}{$uri}	= $code;
	} else {
		our %functions;
		$functions{ $uri }	= $code;
	}
}

=item C<get_function ( $uri )>

If C<$uri> is associated with a query function, returns a CODE reference
to the function. Otherwise returns C<undef>.
=cut

sub get_function {
	my $self	= shift;
	my $uri		= shift;
	
	our %functions;
	my $func	= $self->{'functions'}{$uri} || $functions{ $uri };
	return $func;
}




our %functions;
BEGIN {
	$functions{ 'sparql:regex' }	= sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		my (@from, @where);
		
		my (@regex, @literal, @pattern);
		if (blessed($args[0]) and $args[0]->isa('RDF::Query::Node::Variable')) {
			my $name	= $args[0]->name;
			push(@literal, "${name}_Value");
			push(@literal, "${name}_URI");
			push(@literal, "${name}_Name");
		} else {
			push(@literal, $self->expr2sql( $args[0], $level ));
		}
		
		if ($args[1][0] eq 'VAR') {
			my $name	= $args[0][1];
			push(@pattern, "${name}_Value");
			push(@pattern, "${name}_URI");
			push(@pattern, "${name}_Name");
		} else {
			push(@pattern, $self->expr2sql( $args[1], $level ));
		}
		
		foreach my $literal (@literal) {
			foreach my $pattern (@pattern) {
				push(@regex, sprintf(qq(%s REGEXP %s), $literal, $pattern));
			}
		}
		
		push(@where, '(' . join(' OR ', @regex) . ')');
		return ({}, \@from, \@where);
	};
	
	$functions{ 'sparql:bound' } = sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		my (@from, @where);
		
		my $literal	= $self->expr2sql( $args[0], $level );
		push(@where, sprintf(qq(%s IS NOT NULL), $literal));
		return ({}, \@from, \@where);
	};
	
	$functions{ 'rdfquery:isNotBound' }	= sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		my (@from, @where);
		
		my $literal	= $self->expr2sql( $args[0], $level );
		push(@where, sprintf(qq(%s IS NULL), $literal));
		return ({}, \@from, \@where);
	};
	
	$functions{ 'http://www.w3.org/2001/XMLSchema#integer' }	= sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		my (@from, @where);
		
		my $literal	= $self->expr2sql( $args[0], $level );
		push(@where, sprintf(qq((0 + %s)), $literal));
		return ({}, \@from, \@where);
	};
	
	$functions{ 'http://www.w3.org/2001/XMLSchema#double' }	=
	$functions{ 'http://www.w3.org/2001/XMLSchema#decimal' }	= sub {
		my $self	= shift;
		my $parsed_vars	= shift;
		my $level	= shift || \do{ my $a = 0 };
		my @args	= @_;
		
		my (@from, @where);
		
		if ($args[0] eq 'FUNCTION') {
			Carp::confess;
		}
		
		my $literal	= $self->expr2sql( $args[0], $level );
		push(@where, sprintf(qq((0.0 + %s)), $literal));
		return ({}, \@from, \@where);
	};
}





1;

__END__

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
