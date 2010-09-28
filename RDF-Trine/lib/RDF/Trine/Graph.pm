# RDF::Trine::Graph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Graph - Materialized RDF Graphs for testing isomorphism

=head1 VERSION

This document describes RDF::Trine::Graph version 0.128

=head1 SYNOPSIS

  use RDF::Trine::Graph;
  my $a	= RDF::Trine::Graph->new( $model_a );
  my $b	= RDF::Trine::Graph->new( $model_b );
  print "graphs are " . ($a->equals( $b ) ? "the same" : "different");

=head1 METHODS

=over 4

=cut

package RDF::Trine::Graph;

use strict;
use warnings;
no warnings 'redefine';

use Math::Combinatorics qw(permute);

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '0.128';
}

use overload	'=='	=> \&RDF::Trine::Graph::equals,
				'eq'	=> \&RDF::Trine::Graph::equals;

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use RDF::Trine::Node;
use RDF::Trine::Store::DBI;

=item C<< new ( $model ) >>

=item C<< new ( $iterator ) >>

Returns a new graph from the given RDF::Trine::Model or RDF::Trine::Iterator::Graph object.

=cut

sub new {
	my $class	= shift;
	unless (blessed($_[0])) {
		throw RDF::Trine::Error::MethodInvocationError -text => "RDF::Trine::Graph::new must be called with a Model or Iterator argument";
	}
	
	my %data;
	if ($_[0]->isa('RDF::Trine::Iterator::Graph')) {
		my $iter	= shift;
		my $model	= RDF::Trine::Model->new( RDF::Trine::Store::DBI->temporary_store() );
		while (my $st = $iter->next) {
			$model->add_statement( $st );
		}
		$data{ model }	= $model;
	} elsif ($_[0]->isa('RDF::Trine::Model')) {
		$data{ model }	= shift;
	} else {
		throw RDF::Trine::Error::MethodInvocationError -text => "RDF::Trine::Graph::new must be called with a Model or Iterator argument";
	}
	
	my $self	= bless(\%data, $class);
}

=item C<< equals ( $graph ) >>

Returns true if the invocant and $graph represent two equal RDF graphs (e.g.
there exists a bijection between the RDF statements of the invocant and $graph).

=cut

sub equals {
	my $self	= shift;
	my $graph	= shift;
	unless (blessed($graph) and $graph->isa('RDF::Trine::Graph')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "RDF::Trine::Graph::equals must be called with a Graph argument";
	}
	
	my @graphs	= ($self, $graph);
	my ($ba, $nba)	= $self->split_blank_statements;
	my ($bb, $nbb)	= $graph->split_blank_statements;
	if (scalar(@$nba) != scalar(@$nbb)) {
		my $nbac	= scalar(@$nba);
		my $nbbc	= scalar(@$nbb);
# 		warn "count of non-blank statements didn't match ($nbac != $nbbc)" if ($debug);
		return 0;
	}
	my $bac	= scalar(@$ba);
	my $bbc	= scalar(@$bb);
	if ($bac != $bbc) {
# 		warn "count of blank statements didn't match ($bac != $bbc)" if ($debug);
		return 0;
	}
	
	for ($nba, $nbb) {
		@$_	= sort map { $_->as_string } @$_;
	}
	
	foreach my $i (0 .. $#{ $nba }) {
		unless ($nba->[$i] eq $nbb->[$i]) {
# 			warn "non-blank triples don't match: " . Dumper($nba->[$i], $nbb->[$i]);
			return 0;
		}
	}
	
	if ($bac == 0) {
# 		warn "no blank nodes -- models match\n" if ($debug);
		return 1;
	}
	
	my %blank_ids_a;
	foreach my $st (@$ba) {
		foreach my $n (grep { $_->isa('RDF::Trine::Node::Blank') } $st->nodes) {
			$blank_ids_a{ $n->blank_identifier }++;
		}
	}

	my %blank_ids_b;
	foreach my $st (@$bb) {
		foreach my $n (grep { $_->isa('RDF::Trine::Node::Blank') } $st->nodes) {
			$blank_ids_b{ $n->blank_identifier }++;
		}
	}
	
	my @ka	= keys %blank_ids_a;
	my @kb	= keys %blank_ids_b;
	my @kbp	= permute( @kb );
	MAPPING: foreach my $mapping (@kbp) {
		my %mapping;
		@mapping{ @ka }	= @$mapping;
# 		warn "trying mapping: " . Dumper(\%mapping) if ($debug);
		
		my %bb	= map { $_->as_string => 1 } @$bb;
		foreach my $st (@$ba) {
			my @nodes;
			foreach my $method ($st->node_names) {
				my $n	= $st->$method();
				if ($n->isa('RDF::Trine::Node::Blank')) {
					my $id	= $mapping{ $n->blank_identifier };
# 					warn "mapping " . $n->blank_identifier . " to $id\n" if ($debug);
					push(@nodes, RDF::Trine::Node::Blank->new( $id ));
				} else {
					push(@nodes, $n);
				}
			}
			my $class	= ref($st);
			my $mapped_st	= $class->new( @nodes )->as_string;
# 			warn "checking for '$mapped_st' in " . Dumper(\%bb) if ($debug);
			if ($bb{ $mapped_st }) {
				delete $bb{ $mapped_st };
			} else {
				next MAPPING;
			}
		}
# 		warn "found mapping: " . Dumper(\%mapping) if ($debug);
		return 1;
	}
	
# 	warn "didn't find mapping\n" if ($debug);
	return 0;
}

=item C<< split_blank_statements >>

Returns two array refs, containing triples with blank nodes and triples without
any blank nodes, respectively.

=cut

sub split_blank_statements {
	my $self	= shift;
	my $iter	= $self->get_statements;
	my (@blanks, @nonblanks);
	while (my $st = $iter->next) {
		if ($st->has_blanks) {
			push(@blanks, $st);
		} else {
			push(@nonblanks, $st);
		}
	}
	return (\@blanks, \@nonblanks);
}

=item C<< get_statements >>

Returns a RDF::Trine::Iterator::Graph object for the statements in this graph.

=cut

sub get_statements {
	my $self	= shift;
	return $self->{model}->get_statements();
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
