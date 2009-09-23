# RDF::Query::Parser::SPARQL2
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARQL2 - SPARQL Parser.

=head1 VERSION

This document describes RDF::Query::Parser::SPARQL2 version 2.200, released 6 August 2009.

=head1 SYNOPSIS

 use RDF::Query::Parser::SPARQL2;
 my $parser	= RDF::Query::Parse::SPARQL2->new();
 my $iterator = $parser->parse( $query, $base_uri );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Query::Parser::SPARQL2;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Parser::SPARQL);

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number reftype);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200';
}

######################################################################




# [22] GraphPatternNotTriples ::= OptionalGraphPattern | GroupOrUnionGraphPattern | GraphGraphPattern
sub _GraphPatternNotTriples_test {
	my $self	= shift;
	return 1 if $self->_test(qr/(NOT\s+)?EXISTS/i);
	return $self->SUPER::_GraphPatternNotTriples_test;
}

sub _GraphPatternNotTriples {
	my $self	= shift;
	if ($self->_ExistsGraphPattern_test) {
		$self->_ExistsGraphPattern;
	} else {
		$self->SUPER::_GraphPatternNotTriples;
	}
}

sub __handle_GraphPatternNotTriples {
	my $self	= shift;
	my $data	= shift;
	my ($class, @args)	= @$data;
	if ($class eq 'RDF::Query::Algebra::Exists') {
		my $cont	= $self->_pop_pattern_container;
		my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( @$cont );
		$self->_push_pattern_container;
		unless ($ggp) {
			$ggp	= RDF::Query::Algebra::GroupGraphPattern->new();
		}
		my $pat	= $class->new( $ggp, @args );
		$self->_add_patterns( $pat );
	} else {
		$self->SUPER::__handle_GraphPatternNotTriples( $data );
	}
}


# ExistsGraphPattern ::= 'NOT'? 'EXISTS' GroupGraphPattern
sub _ExistsGraphPattern_test {
	my $self	= shift;
	return $self->_test( qr/(NOT\s+)?EXISTS/i );
}

sub _ExistsGraphPattern {
	my $self	= shift;
	my $op		= $self->_eat( qr/(NOT\s+)?EXISTS/i );
	my $not		= ($op =~ /^NOT/i) ? 1 : 0;
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	my $pat		= ['RDF::Query::Algebra::Exists', $ggp, $not];
	$self->_add_stack( $pat );
}



1;

__END__
