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
	return 1 if $self->_test(qr/SERVICE/i);
	return $self->SUPER::_GraphPatternNotTriples_test;
}

sub _GraphPatternNotTriples {
	my $self	= shift;
	if ($self->_test(qr/SERVICE/i)) {
		$self->_ServiceGraphPattern;
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

sub __handle_GraphPatternNotTriples {
	my $self	= shift;
	my $data	= shift;
	my ($class, @args)	= @$data;
	if ($class eq 'RDF::Query::Algebra::Service') {
# 		my $ggp	= $self->_remove_pattern();
# 		unless ($ggp) {
# 			$ggp	= RDF::Query::Algebra::GroupGraphPattern->new();
# 		}
# 		my $opt	= $class->new( $ggp, @args );
# 		$self->_add_patterns( $opt );
	} else {
		$self->SUPER::__handle_GraphPatternNotTriples( $data );
	}
}




1;


__END__

