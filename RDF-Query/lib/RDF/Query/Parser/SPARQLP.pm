# RDF::Query::Parser::SPARQL
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARQLP - Extended SPARQL Parser.

=head1 VERSION

This document describes RDF::Query::Parser::SPARQLP version 2.200_01, released XX July 2009.

=head1 SYNOPSIS

 use RDF::Query::Parser::SPARQLP;
 my $parser	= RDF::Query::Parse::SPARQLP->new();
 my $iterator = $parser->parse( $query, $base_uri );

=head1 DESCRIPTION

...

=cut

package RDF::Query::Parser::SPARQLP;

use strict;
use warnings;
use base qw(RDF::Query::Parser::SPARQL);

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number reftype);

our $r_AGGREGATE_CALL	= qr/MIN|MAX|COUNT|AVG/i;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200_01';
}

######################################################################


sub __solution_modifiers {
	my $self	= shift;
	my $aggdata	= delete( $self->{build}{__aggregate} );
	if ($aggdata) {
		my $groupby	= delete( $self->{build}{__group_by} ) || [];
		my $pattern	= $self->{build}{triples};
		my $ggp		= shift(@$pattern);
		my $agg		= RDF::Query::Algebra::Aggregate->new( $ggp, $groupby, %{ $aggdata } );
		push(@{ $self->{build}{triples} }, $agg);
	}
	$self->SUPER::__solution_modifiers( @_ );
}

# [22] GraphPatternNotTriples ::= OptionalGraphPattern | GroupOrUnionGraphPattern | GraphGraphPattern
sub _GraphPatternNotTriples_test {
	my $self	= shift;
	return 1 if $self->_test(qr/UNSAID|SERVICE|TIME/i);
	return $self->SUPER::_GraphPatternNotTriples_test;
}

sub _GraphPatternNotTriples {
	my $self	= shift;
	if ($self->_test(qr/SERVICE/i)) {
		$self->_ServiceGraphPattern;
	} elsif ($self->_test(qr/TIME/i)) {
		$self->_TimeGraphPattern;
	} elsif ($self->_NotGraphPattern_test) {
		$self->_NotGraphPattern;
	} else {
		$self->SUPER::_GraphPatternNotTriples;
	}
}

sub _ServiceGraphPattern {
	my $self	= shift;
	$self->_eat( qr/SERVICE/i );
	$self->__consume_ws_opt;
	$self->_IRIref;
	my ($iri)	= splice( @{ $self->{stack} } );
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	
	my $pattern	= RDF::Query::Algebra::Service->new( $iri, $ggp );
	$self->_add_patterns( $pattern );
	
	my $opt		= ['RDF::Query::Algebra::Service', $iri, $ggp];
	$self->_add_stack( $opt );
}

sub _TimeGraphPattern {
	my $self	= shift;
	$self->_eat( qr/TIME/i );
	$self->__consume_ws_opt;
	
	my ($interval, $timetriples);
	if ($self->_test( qr/[\$?]/ )) {
		# get a variable as the time context
		$self->_Var;
		($interval)		= splice(@{ $self->{stack} });
		$timetriples	= RDF::Query::Algebra::BasicGraphPattern->new();
	} else {
		$self->_push_pattern_container;
		# get a bnode as the time context
		$self->_BlankNodePropertyListMaybeEmpty;
		($interval)		= splice(@{ $self->{stack} });
		my $array		= $self->_pop_pattern_container;
		$timetriples	= RDF::Query::Algebra::BasicGraphPattern->new( @$array );
	}
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	
	my $pattern	= RDF::Query::Algebra::TimeGraph->new( $interval, $ggp, $timetriples );
	$self->_add_patterns( $pattern );
	
	my $opt		= ['RDF::Query::Algebra::TimeGraph', $interval, $ggp, $timetriples];
	$self->_add_stack( $opt );
}

sub __handle_GraphPatternNotTriples {
	my $self	= shift;
	my $data	= shift;
	my ($class, @args)	= @$data;
	if ($class eq 'RDF::Query::Algebra::Service') {
	} elsif ($class eq 'RDF::Query::Algebra::TimeGraph') {
	} elsif ($class eq 'RDF::Query::Algebra::Not') {
		my $cont	= $self->_pop_pattern_container;
		my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( @$cont );
		$self->_push_pattern_container;
		# my $ggp	= $self->_remove_pattern();
		unless ($ggp) {
			$ggp	= RDF::Query::Algebra::GroupGraphPattern->new();
		}
		my $not	= $class->new( $ggp, @args );
		$self->_add_patterns( $not );
	} else {
		$self->SUPER::__handle_GraphPatternNotTriples( $data );
	}
}

sub _BlankNodePropertyListMaybeEmpty {
	my $self	= shift;
	$self->_eat('[');
	$self->__consume_ws_opt;
	$self->_PropertyList;
	$self->__consume_ws_opt;
	$self->_eat(']');
	
	my @props	= splice(@{ $self->{stack} });
	my $subj	= $self->new_blank;
	my @triples	= map { RDF::Query::Algebra::Triple->new( $subj, @$_ ) } @props;
	$self->_add_patterns( @triples );
	$self->_add_stack( $subj );
}

sub _BrackettedAliasExpression {
	my $self	= shift;
	$self->_eat('(');
	$self->__consume_ws_opt;
	$self->_Expression;
	my ($expr)	= splice(@{ $self->{stack} });
	$self->__consume_ws_opt;
	$self->_eat('AS');
	$self->__consume_ws_opt;
	$self->_Var;
	my ($var)	= splice(@{ $self->{stack} });
	$self->__consume_ws_opt;
	$self->_eat(')');
	
	my $alias	= $self->new_alias_expression( $var, $expr );
	$self->_add_stack( $alias );
}

sub __SelectVar_test {
	my $self	= shift;
	local($self->{__aggregate_call_ok})	= 1;
	return ($self->_BuiltInCall_test or $self->_test( qr/[(]/i) or $self->SUPER::__SelectVar_test);
}

sub __SelectVar {
	my $self	= shift;
	local($self->{__aggregate_call_ok})	= 1;
	if ($self->_test('(')) {
		$self->_BrackettedAliasExpression;
	} elsif ($self->_BuiltInCall_test) {
		$self->_BuiltInCall;
	} else {
		$self->SUPER::__SelectVar;
	}
}

sub __Aggregate {
	my $self	= shift;
	my $op	= uc( $self->_eat( $r_AGGREGATE_CALL ) );
	$self->_eat('(');
	$self->__consume_ws_opt;
	my $expr;
	my $distinct	= 0;
	if ($self->_test('*')) {
		$expr	= $self->_eat('*');
	} else {
		if ($op eq 'COUNT' and $self->_test( qr/DISTINCT/i )) {
			$self->_eat( qr/DISTINCT\s*/i );
			$distinct	= 1;
		}
		$self->_Expression;
		($expr)	= splice(@{ $self->{stack} });
	}
	$self->__consume_ws_opt;
	
	my $arg	= blessed($expr) ? $expr->as_sparql : $expr;
	if ($distinct) {
		$arg	= 'DISTINCT ' . $arg;
	}
	my $name	= sprintf('%s(%s)', $op, $arg);
	$self->_eat(')');
	
	$self->{build}{__aggregate}{ $name }	= [ (($distinct) ? "${op}-DISTINCT" : $op), $expr ];
	$self->_add_stack( $self->new_variable($name) );
	
}

sub _BuiltInCall_test {
	my $self	= shift;
	if ($self->{__aggregate_call_ok}) {
		return 1 if ($self->_test( $r_AGGREGATE_CALL ));
	}
	return $self->SUPER::_BuiltInCall_test;
}

sub _BuiltInCall {
	my $self	= shift;
	if ($self->{__aggregate_call_ok} and $self->_test( $r_AGGREGATE_CALL )) {
		$self->__Aggregate;
	} else {
		$self->SUPER::_BuiltInCall;
	}
}

sub _WhereClause {
	my $self	= shift;
	$self->SUPER::_WhereClause;
	
	$self->__consume_ws_opt;
	if ($self->_test( qr/BINDINGS/i )) {
		$self->_eat( qr/BINDINGS/i );
		
		my @vars;
		$self->__consume_ws_opt;
		$self->_Var;
		push( @vars, splice(@{ $self->{stack} }));
		$self->__consume_ws_opt;
		while ($self->_test(qr/[\$?]/)) {
			$self->_Var;
			push( @vars, splice(@{ $self->{stack} }));
			$self->__consume_ws_opt;
		}
		
		$self->_eat('{');
		$self->__consume_ws_opt;
		while ($self->_Binding_test) {
			$self->_Binding;
			$self->__consume_ws_opt;
		}
		$self->_eat('}');
		
		$self->{build}{bindings}{vars}	= \@vars;
		$self->__consume_ws_opt;
	}

	$self->__consume_ws_opt;
	if ($self->_test( qr/GROUP\s+BY/i )) {
		$self->_eat( qr/GROUP\s+BY/i );
		
		my @vars;
		$self->__consume_ws_opt;
		$self->__GroupByVar;
		push( @vars, splice(@{ $self->{stack} }));
		$self->__consume_ws_opt;
		while ($self->__GroupByVar_test) {
			$self->__GroupByVar;
			push( @vars, splice(@{ $self->{stack} }));
			$self->__consume_ws_opt;
		}
		$self->{build}{__group_by}	= \@vars;
		$self->__consume_ws_opt;
	}
}

sub _Binding_test {
	my $self	= shift;
	return $self->_test( '(' );
}

sub _Binding {
	my $self	= shift;
	$self->_eat( '(' );
	$self->__consume_ws_opt;
	
	my @terms;
	$self->__consume_ws_opt;
	$self->_VarOrTerm;
	push( @terms, splice(@{ $self->{stack} }));
	$self->__consume_ws_opt;
	while ($self->_VarOrTerm_test) {
		$self->_VarOrTerm;
		push( @terms, splice(@{ $self->{stack} }));
		$self->__consume_ws_opt;
	}
	push( @{ $self->{build}{bindings}{terms} }, \@terms );
	$self->__consume_ws_opt;
	$self->_eat( ')' );
}

sub __GroupByVar_test {
	my $self	= shift;
	return ($self->_BuiltInCall_test or $self->_test( qr/[(]/i) or $self->SUPER::__SelectVar_test);
}

sub __GroupByVar {
	my $self	= shift;
	if ($self->_test('(')) {
		$self->_BrackettedAliasExpression;
	} elsif ($self->_BuiltInCall_test) {
		$self->_BuiltInCall;
	} else {
		$self->SUPER::__SelectVar;
	}
}



################################################################################
### ARQ Property Paths
### http://jena.sourceforge.net/ARQ/property_paths.html

# verb test is the same as normal with the addition of parens for path groups and caret for reverse
sub _Verb_test {
	my $self	= shift;
	if ($self->_test(qr/[(^]/)) {
		return 1;
	} else {
		return $self->SUPER::_Verb_test;
	}
}


sub __strip_path_identifier {
	my $node	= shift;
	if (reftype($node) eq 'ARRAY' and $node->[0] eq 'PATH') {
		# strip the 'PATH' identifier off the front of the pattern
		$node	= $node->[1];
	}
	return $node;
}

sub _Verb {
	my $self	= shift;
	
	my $path	= 0;
	if ($self->_test(qr/\(/)) {
		$path	= 1;
		$self->_eat('(');
		$self->__consume_ws_opt;
		$self->_Verb;
		my $verb	= __strip_path_identifier( splice( @{ $self->{stack} } ) );
		
		# keep the parens so we can round-trip serialization easily
		$self->_add_stack( [ '(', $verb ] );
		$self->__consume_ws_opt;
		$self->_eat(')');
	} elsif ($self->_test(qr/\^/)) {
		$path	= 1;
		$self->_eat('^');
		$self->__consume_ws_opt;
		$self->SUPER::_Verb;
		my $verb	= splice( @{ $self->{stack} } );
		$self->_add_stack( [ '^', $verb ] );
	} else {
		$self->SUPER::_Verb;
	}
	
	my ($verb)	= __strip_path_identifier( splice( @{ $self->{stack} } ) );
	
	BLOCK: {
		# XXX we should match a '?' here, too, but it can mistake a variable for
		# XXX a path modifier (as in { ?s a ?o }), and then fail to match the variable
		# XXX (since the '?' has been eaten). This has to be fixed by updating the
		# XXX parser to do proper tokenizing.
		if ($path or $self->_test(qr#[*+{/^|]#)) {
			# unary operators
			if ($self->_test(qr#[*?+{]#)) {
				if ($self->_test(qr/[+][0-9.]/)) {
					# the '+' should belong to the INTEGER or DECIMAL that follows the predicate
					# so break out, and leave the '+' to be parsed later
					last BLOCK;
				}
				my ($unop) = $self->_eat(qr#[*?+{]#);
				if ($unop eq '{') {
					# RANGE and EXACT ops. Use '{' for ranges (including unbounded)
					# and 'x' for exact repetitions. So 'elt*' is ['{',elt,0] while
					# 'elt{2}' is ['x',elt,2]
					my $exact;
					my @range	= $self->_eat(qr/(\d+)/);
					if ($self->_test(',')) {
						$exact	= 0;	# range (vs. exact)
						$self->_eat(',');
						if ($self->_test(qr/\d/)) {
							my ($to)	= $self->_eat(qr/(\d+)/);
							push(@range, $to);
						}
					} else {
						$exact	= 1;	# exact (vs. range)
					}
					$self->_eat('}');
					my $op	= ($exact ? 'x' : '{');
					$verb	= [ $op, $verb, @range ];
				} elsif ($unop eq '*') {
					# kleene star is equivalent to {0,}
					$verb	= [ '{', $verb, 0 ];
				} elsif ($unop eq '?') {
					# ? is equivalent to {0,1}
					$verb	= [ '{', $verb, 0, 1 ];
				} elsif ($unop eq '+') {
					# + is equivalent to {1,}
					$verb	= [ '{', $verb, 1 ];
				}
			}
			
			$self->__consume_ws_opt;
			
			# binary operators
			while ($self->_test(qr#[/^|]#)) {
				my ($binop) = $self->_eat(qr#[/^|]#);
				$self->__consume_ws_opt;
				$self->_Verb;
				my ($rhs)	= __strip_path_identifier( splice( @{ $self->{stack} } ) );
				$verb		= [ $binop, $verb, $rhs ];
			}
			
			$self->_add_stack( ['PATH', $verb] );
			return;
		}
	}
	
	$self->_add_stack( $verb );
}

sub _TriplesBlock {
	my $self	= shift;
	$self->_push_pattern_container;
	$self->__TriplesBlock;
	my @triples		= @{ $self->_pop_pattern_container };
	
	my @paths;
	for (my $i = $#triples; $i >= 0; $i--) {
		my $t	= $triples[$i];
		my $p	= $t->predicate;
		if (reftype($p) eq 'ARRAY' and $p->[0] eq 'PATH') {
			splice(@triples, $i, 1);
			my $start	= $t->subject;
			my $end		= $t->object;
			my $path	= RDF::Query::Algebra::Path->new( $start, $p->[1], $end );
			push(@paths, $path);
		}
	}
	my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @triples );
	if (@paths) {
		my $ggp	= RDF::Query::Algebra::GroupGraphPattern->new( $bgp, @paths );
		$self->_add_patterns( $ggp );
	} else {
		$self->_add_patterns( $bgp );
	}
}

# NotGraphPattern ::= 'UNSAID' GroupGraphPattern
sub _NotGraphPattern_test {
	my $self	= shift;
	return $self->_test( qr/UNSAID/i );
}

sub _NotGraphPattern {
	my $self	= shift;
	$self->_eat( qr/UNSAID/i );
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	my $opt		= ['RDF::Query::Algebra::Not', $ggp];
	$self->_add_stack( $opt );
}



1;


__END__

