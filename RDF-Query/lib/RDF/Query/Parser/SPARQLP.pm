# RDF::Query::Parser::SPARQL
# -------------
# $Revision: 127 $
# $Date: 2006-02-08 14:53:21 -0500 (Wed, 08 Feb 2006) $
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
our $VERSION	= '1.000';

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number);
use List::MoreUtils qw(uniq);



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




1;


__END__

