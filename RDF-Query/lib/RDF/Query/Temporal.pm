# RDF::Query::Temporal
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Temporal - tSPARQL temporal extensions to the RDF::Query engine.

=head1 VERSION

This document describes RDF::Query::Temporal version 2.918.

=cut

package RDF::Query::Temporal;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query);

use Scalar::Util qw(blessed);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=begin private

=item C<query_more_time ( bound => \%bound, triples => \@triples )>

Called by C<query_more()> to handle TIME graph query patterns.

=end private

=cut

sub query_more_time {
	my $self		= shift;
	my %args		= @_;
	if ($args{quad}) {
		throw RDF::Query::Error::QueryPatternError ( -text => "Can't use nested temporal queries" );
	}
	
	my $triples		= delete($args{triples});
	my @triples	= @{$triples};
	my $triple	= shift(@triples);
	
	return $self->query_more( triples => [ $triple->pattern ], %args, quad => $triple->interval );
}

=begin private

=item C<fixup_pattern ( $pattern )>

Called by fixup() with individual graph patterns. Returns a list of sub-patterns
that may need fixing up.

=end private

=cut

sub fixup_pattern {
	my $self	= shift;
	my $triple	= shift;
	my $bridge		= $self->{bridge};
	
	if ($triple->isa('RDF::Query::Algebra::TimeGraph')) {
		my @triples;
		push(@triples, $triple->pattern);
		push(@triples, $triple->time_triples);
		
		use Data::Dumper;
		warn Dumper(\@triples);
		if ($triple->interval->isa('RDF::Query::Node::Resource')) {
			$triple->interval( $bridge->new_resource( $triple->interval->uri_value ) );
		} elsif ($triple->interval->isa('RDF::Query::Node::Variable')) {
			my $var	= $triple->interval->name;
			$self->{ known_variables_hash }{ $var }++
		}
		return @triples;
	} else {
		return $self->SUPER::fixup_pattern( $triple );
	}
}

1;

__END__

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
