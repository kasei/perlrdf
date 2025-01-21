# RDF::Query::BGPOptimizer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::BGPOptimizer - Optimizer for ordering the joins of triple patterns in a BGP

=head1 VERSION

This document describes RDF::Query::BGPOptimizer version 2.918.

=head1 STATUS

This module's API and functionality should be considered unstable.
In the future, this module may change in backwards-incompatible ways,
or be removed entirely. If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 METHODS

=over 4

=cut

package RDF::Query::BGPOptimizer;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);
use Scalar::Util qw(blessed reftype refaddr);
use RDF::Query::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=item C<< ordered_triples ( $context, @triples ) >>

Returns a list of triples, ordered so as to optimize a left-deep join plan based
on the frequency counts provided by the underlying model.

=cut

sub ordered_triples {
	my $self	= shift;
	my $context	= shift;
	my @triples	= @_;
	
	my $model	= $context->model;
	
	my %vars;
	my %seen;
	my @weighted	= map {
		my $triple		= RDF::Query::Plan::Triple->new( $_->nodes );
		[ $_, $self->_cost( $triple, $context ) ]
	} @triples;
	my %triples		= map { refaddr($_->[0]) => $_ } @weighted;
	my @ordered	= sort { $a->[1] <=> $b->[1] } @weighted;
	
	foreach my $t (@triples) {
		my @vars		= $self->_triple_vars( $t );
		foreach my $name (@vars) {
			push( @{ $vars{ $name } }, $t ) unless ($seen{ $name }{ refaddr($t) }++);
		}
	}
	
	my %edges;
	foreach my $name (keys %vars) {
		my @triples	= @{ $vars{ $name } };
		foreach my $t (@triples) {
			my $ta	= refaddr($t);
			foreach my $u (@triples) {
				my $ua	= refaddr($u);
				next if ($ta == $ua);
				$edges{ $ta }{ $ua }	= $u;
			}
		}
	}
	
	
	my @final;
	my %used;
	my $start	= shift(@ordered);
	$used{ refaddr($start) }++;
	push(@final, $start);
	
	my @seen	= refaddr($start->[0]);
	my $count	= 0;
	while (@ordered) {
		if (++$count > scalar(@triples)) {
			die "loop in BGPOptimizer (?)";
		}
		
		my @frontier	= grep { not($used{refaddr($_)}) } map { $triples{ $_ } } map { keys(%{ $edges{ $_ } }) } @seen;
		my @orderedf	= sort { $a->[1] <=> $b->[1] } @frontier;
		if (@orderedf) {
			my $next	= shift(@orderedf);
			my $addr	= refaddr($next);
			$used{ $addr }++;
			push(@final, $next);
			push(@seen, refaddr($next->[0]));
			@ordered	= grep { refaddr($_) != $addr } @ordered;
		} else {
			my $next	= shift(@ordered);
			my $addr	= refaddr($next);
			$used{ $addr }++;
			push(@final, $next);
			push(@seen, refaddr($next->[0]));
		}
	}
	
	return map { $_->[0] } @final;
}

sub _cost {
	my $self	= shift;
	my $pattern	= shift;
	my $context	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.bgpoptimizer");
	my $bf		= $pattern->bf( $context );
	my $f		= ($bf =~ tr/f//);
	my $r		= $f / 3;
	$l->debug( "Pattern has bf representation '$bf'" );
	$l->debug( "There are $f of 3 free variables" );
	$l->debug( 'Estimated cardinality of triple is : ' . $r );
	
	# round the cardinality to an integer
	return int($r + .5 * ($r <=> 0));
}

sub _triple_vars {
	my $self	= shift;
	my $t		= shift;
	my @nodes	= $t->nodes;
	my (@vars, %seen);
	foreach my $n (@nodes) {
		if ($n->isa('RDF::Trine::Node::Variable')) {
			my $name	= $n->name;
			push(@vars, $name) unless ($seen{ $name }++);
		}
	}
	return @vars;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
