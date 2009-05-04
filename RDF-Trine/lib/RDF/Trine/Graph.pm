# RDF::Trine::Graph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Graph - Graph class

=head1 METHODS

=over 4

=cut

package RDF::Trine::Graph;

use strict;
use warnings;
no warnings 'redefine';

use Math::Combinatorics qw(permute);

our ($VERSION);
BEGIN {
	$VERSION	= '0.110';
}

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use RDF::Trine::Node;
use RDF::Trine::Store::DBI;

=item C<< new ( $model ) >>

=item C<< new ( $iterator ) >>

Returns a new graph from the given ::Model or ::Iterator::Graph object.

=cut

sub new {
	my $class	= shift;
	unless (blessed($_[0])) {
		throw RDF::Trine::Error::MethodInvocationError -text => "RDF::Trine::Graph::new must be called with a Model or Iterator argument";
	}
	
	my %data;
	if ($_[0]->isa('RDF::Trine::Iterator::Graph')) {
		$data{ type }	= 'iter';
		$data{ iter }	= shift;
	} elsif ($_[0]->isa('RDF::Trine::Model')) {
		$data{ type }	= 'model';
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
	return 0 if (scalar(@$nba) != scalar(@$nbb));
	return 0 if (scalar(@$ba) != scalar(@$bb));
	
	for ($nba, $nbb) {
		@$_	= sort map { $_->as_string } @$_;
	}
	
	foreach my $i (0 .. $#{ $nba }) {
		return 0 unless ($nba->[$i] eq $nbb->[$i]);
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
# 		warn "trying mapping: " . Dumper(\%mapping);
		
		my %bb	= map { $_->as_string => 1 } @$bb;
		foreach my $st (@$ba) {
			my @nodes;
			foreach my $method ($st->node_names) {
				my $n	= $st->$method();
				if ($n->is_blank) {
					my $id	= $mapping{ $n->blank_identifier };
# 					warn "mapping " . $n->blank_identifier . " to $id\n";
					push(@nodes, RDF::Trine::Node::Blank->new( $id ));
				} else {
					push(@nodes, $n);
				}
			}
			my $class	= ref($st);
			my $mapped_st	= $class->new( @nodes )->as_string;
# 			warn "checking for '$mapped_st' in " . Dumper(\%bb);
			if ($bb{ $mapped_st }) {
				delete $bb{ $mapped_st };
			} else {
				next MAPPING;
			}
		}
# 		warn "found mapping: " . Dumper(\%mapping);
		return 1;
	}
	
	return 0;
}

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

sub get_statements {
	my $self	= shift;
	if ($self->{type} eq 'model') {
		return $self->{model}->get_statements();
	} elsif ($self->{type} eq 'iter') {
		return $self->{iter};
	} else {
		throw RDF::Trine::Error -text => "Unrecognized graph type";
	}
}

sub _sort_statements ($$) {
	return 1 if ($_[0]->has_blanks);
	return -1 if ($_[1]->has_blanks);
	for my $method (qw(subject predicate object)) {
		my ($a, $b)	= map { $_->$method()->as_string } @_;
		my $c		= ($a cmp $b);
		return $c if ($c);
	}
	return 0;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
