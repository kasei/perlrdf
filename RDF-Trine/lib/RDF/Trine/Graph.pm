# RDF::Trine::Graph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Graph - Materialized RDF Graphs for testing isomorphism

=head1 VERSION

This document describes RDF::Trine::Graph version 1.012

=head1 SYNOPSIS

  use RDF::Trine::Graph;
  my $a	= RDF::Trine::Graph->new( $model_a );
  my $b	= RDF::Trine::Graph->new( $model_b );
  print "graphs are " . ($a->equals( $b ) ? "the same" : "different");

=head1 DESCRIPTION

RDF::Trine::Graph provdes a mechanism for testing graph isomorphism based on
graph triples from either a RDF::Trine::Model or a RDF::Trine::Iterator.
Isomorphism testing requires materializing all of a graph's triples in memory,
and so should be used carefully in situations with large graphs.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Graph;

use strict;
use warnings;
no warnings 'redefine';

use Algorithm::Combinatorics qw(permutations);

our ($VERSION, $debug, $AUTOLOAD);
BEGIN {
	$debug		= 0;
	$VERSION	= '1.012';
}

use overload
	'=='	=> \&RDF::Trine::Graph::_eq,
	'eq'	=> \&RDF::Trine::Graph::_eq,
	'le'	=> \&RDF::Trine::Graph::_le,
	'ge'	=> \&RDF::Trine::Graph::_ge,
	'lt'	=> \&RDF::Trine::Graph::_lt,
	'gt'	=> \&RDF::Trine::Graph::_gt,
	;

sub _eq {
	my ($x, $y) = @_;
	return $x->equals($y);
}

sub _le {
	my ($x, $y) = @_;
	return $x->is_subgraph_of($y);
}

sub _ge {
	return _le(@_[1,0]);
}

sub _lt {
	my ($x, $y) = @_;
#	Test::More::diag(sprintf('%s // %s', ref($x), ref($y)));
	return ($x->size < $y->size) && ($x->is_subgraph_of($y));
}

sub _gt {
	return _lt(@_[1,0]);
}

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use RDF::Trine::Node;
use RDF::Trine::Store;

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
		my $model	= RDF::Trine::Model->new( RDF::Trine::Store->temporary_store() );
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
	my $self  = shift;
	my $graph = shift;
	undef($self->{error});
	return $self->_check_equality($graph) ? 1 : 0;
}

sub _check_equality {
	my $self	= shift;
	my $graph	= shift;
	unless (blessed($graph) and $graph->isa('RDF::Trine::Graph')) {
		$self->{error}	= "RDF::Trine::Graph::equals must be called with a Graph argument";
		throw RDF::Trine::Error::MethodInvocationError -text => $self->{error};
	}
	
	my @graphs	= ($self, $graph);
	my ($ba, $nba)	= $self->split_blank_statements;
	my ($bb, $nbb)	= $graph->split_blank_statements;
	if (scalar(@$nba) != scalar(@$nbb)) {
		my $nbac	= scalar(@$nba);
		my $nbbc	= scalar(@$nbb);
		$self->{error}	= "count of non-blank statements didn't match ($nbac != $nbbc)";
		return 0;
	}
	my $bac	= scalar(@$ba);
	my $bbc	= scalar(@$bb);
	if ($bac != $bbc) {
		$self->{error}	= "count of blank statements didn't match ($bac != $bbc)";
		return 0;
	}
	
	for ($nba, $nbb) {
		@$_	= sort map { $_->as_string } @$_;
	}
	
	foreach my $i (0 .. $#{ $nba }) {
		unless ($nba->[$i] eq $nbb->[$i]) {
			$self->{error}	= "non-blank triples don't match: " . Dumper($nba->[$i], $nbb->[$i]);
			return 0;
		}
	}
	
	return _find_mapping($self, $ba, $bb);
}

=item C<< is_subgraph_of ( $graph ) >>

Returns true if the invocant is a subgraph of $graph. (i.e. there exists an
injection of RDF statements from the invocant to $graph.)

=cut

sub is_subgraph_of {
	my $self  = shift;
	my $graph = shift;
	undef($self->{error});
	return $self->_check_subgraph($graph) ? 1 : 0;
}

=item C<< injection_map ( $graph ) >>

If the invocant is a subgraph of $graph, returns a mapping of blank node
identifiers from the invocant graph to $graph as a hashref. Otherwise
returns false. The solution is not always unique; where there exist multiple
solutions, the solution returned is arbitrary.

=cut

sub injection_map {
	my $self  = shift;
	my $graph = shift;
	undef($self->{error});
	my $map   = $self->_check_subgraph($graph);
	return $map if $map;
	return;
}

sub _check_subgraph {
	my $self	= shift;
	my $graph	= shift;
	unless (blessed($graph) and $graph->isa('RDF::Trine::Graph')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "RDF::Trine::Graph::equals must be called with a Graph argument";
	}
	
	my @graphs	= ($self, $graph);
	my ($ba, $nba)	= $self->split_blank_statements;
	my ($bb, $nbb)	= $graph->split_blank_statements;
	
	if (scalar(@$nba) > scalar(@$nbb)) {
		$self->{error}	= "invocant had too many blank node statements to be a subgraph of argument";
		return 0;
	} elsif (scalar(@$ba) > scalar(@$bb)) {
		$self->{error}	= "invocant had too many non-blank node statements to be a subgraph of argument";
		return 0;
	}

	my %NBB = map { $_->as_string => 1 } @$nbb;
	
	foreach my $st (@$nba) {
		unless ($NBB{ $st->as_string }) {
			return 0;
		}
	}
	
	return _find_mapping($self, $ba, $bb);
}

sub _find_mapping {
	my ($self, $ba, $bb) = @_;

	if (scalar(@$ba) == 0) {
		return {};
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
	
	my %bb_master	= map { $_->as_string => 1 } @$bb;
	
	my @ka	= keys %blank_ids_a;
	my @kb	= keys %blank_ids_b;
	my $kbp	= permutations( \@kb );
	my $count	= 0;
	MAPPING: while (my $mapping = $kbp->next) {
		my %mapping;
		@mapping{ @ka }	= @$mapping;
		warn "trying mapping: " . Dumper(\%mapping) if ($debug);
		
		my %bb	= %bb_master;
		foreach my $st (@$ba) {
			my @nodes;
			foreach my $method ($st->node_names) {
				my $n	= $st->$method();
				if ($n->isa('RDF::Trine::Node::Blank')) {
					my $id	= $mapping{ $n->blank_identifier };
					warn "mapping " . $n->blank_identifier . " to $id\n" if ($debug);
					push(@nodes, RDF::Trine::Node::Blank->new( $id ));
				} else {
					push(@nodes, $n);
				}
			}
			my $class	= ref($st);
			my $mapped_st	= $class->new( @nodes )->as_string;
			warn "checking for '$mapped_st' in " . Dumper(\%bb) if ($debug);
			if ($bb{ $mapped_st }) {
				delete $bb{ $mapped_st };
			} else {
				next MAPPING;
			}
		}
		$self->{error}	=  "found mapping: " . Dumper(\%mapping) if ($debug);
		return \%mapping;
	}
	
	$self->{error}	=  "didn't find blank node mapping\n";
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

# The code below actually goes further now and makes RDF::Trine::Graph
# into a subclass of RDF::Trine::Model via object delegation. This feature
# is undocumented as it's not clear whether this is desirable or not.

=begin private

=item C<< isa >>

=cut

sub isa {
	my ($proto, $queried) = @_;
	$proto = ref($proto) if ref($proto);
	return UNIVERSAL::isa($proto, $queried) || RDF::Trine::Model->isa($queried);
}

=item C<< can >>

=cut

sub can {
	my ($proto, $queried) = @_;
	$proto = ref($proto) if ref($proto);
	return UNIVERSAL::can($proto, $queried) || RDF::Trine::Model->can($queried);
}

sub AUTOLOAD {
	my $self = shift;
	return if $AUTOLOAD =~ /::DESTROY$/;
	$AUTOLOAD =~ s/^(.+)::([^:]+)$/$2/;
	return $self->{model}->$AUTOLOAD(@_);
}

=end private

=item C<< error >>

Returns an error string explaining the last failed C<< equal >> call.

=cut

sub error {
	my $self	= shift;
	return $self->{error};
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
