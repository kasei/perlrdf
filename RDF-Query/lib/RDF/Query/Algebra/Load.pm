# RDF::Query::Algebra::Load
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Load - Algebra class for LOAD operations

=head1 VERSION

This document describes RDF::Query::Algebra::Load version 2.901_01.

=cut

package RDF::Query::Algebra::Load;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %TRIPLE_LABELS;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.901_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $url )>

Returns a new LOAD structure.

=cut

sub new {
	my $class	= shift;
	my $url		= shift;
	my $graph	= shift;
	return bless([$url, $graph], $class);
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->url, $self->graph);
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $url		= $self->url;
	my $graph	= $self->graph;
	my $string;
	if ($graph) {
		$string	= sprintf(
			"(load <%s> <%s>)",
			$url->uri_value,
			$graph->uri_value,
		);
	} else {
		$string	= sprintf(
			"(load <%s>)",
			$url->uri_value,
		);
	}
	return $string;
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $url		= $self->url;
	my $graph	= $self->graph;
	my $string;
	if ($graph) {
		$string	= sprintf(
			"LOAD <%s> INTO GRAPH <%s>",
			$url->uri_value,
			$graph->uri_value,
		);
	} else {
		$string	= sprintf(
			"LOAD <%s>",
			$url->uri_value,
		);
	}
	return $string;
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	return;
}

=item C<< referenced_variables >>

=cut

sub referenced_variables {
	my $self	= shift;
	return;
}

=item C<< url >>

=cut

sub url {
	my $self	= shift;
	return $self->[0];
}

=item C<< graph >>

=cut

sub graph {
	my $self	= shift;
	return $self->[1];
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
