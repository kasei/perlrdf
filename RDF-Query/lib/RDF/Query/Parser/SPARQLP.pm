# RDF::Query::Parser::SPARQL
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARQLP - Extended SPARQL Parser.

=head1 VERSION

This document describes RDF::Query::Parser::SPARQLP version 1.000

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
our $VERSION		= '2.002';

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number);
use List::MoreUtils qw(uniq);

our $r_AGGREGATE_CALL	= qr/MIN|MAX|COUNT/i;

sub _Query {
	my $self	= shift;
	$self->SUPER::_Query;
	my $aggdata	= delete( $self->{build}{__aggregate} );
	if ($aggdata) {
		my $groupby	= delete( $self->{build}{__group_by} ) || [];
		my $pattern	= $self->{build}{triples};
		my $ggp		= shift(@$pattern);
		my $agg		= RDF::Query::Algebra::Aggregate->new( $ggp, $groupby, %{ $aggdata } );
		push(@{ $self->{build}{triples} }, $agg);
	}
}

# [22] GraphPatternNotTriples ::= OptionalGraphPattern | GroupOrUnionGraphPattern | GraphGraphPattern
sub _GraphPatternNotTriples_test {
	my $self	= shift;
	return 1 if $self->_test(qr/SERVICE|TIME/i);
	return $self->SUPER::_GraphPatternNotTriples_test;
}

sub _GraphPatternNotTriples {
	my $self	= shift;
	if ($self->_test(qr/SERVICE/i)) {
		$self->_ServiceGraphPattern;
	} elsif ($self->_test(qr/TIME/i)) {
		$self->_TimeGraphPattern;
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

1;


__END__

