# RDF::Query::Algebra::Shorthand
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Shorthand - Base class for Algebra expressions

=head1 VERSION

This document describes RDF::Query::Algebra::Shorthand version 2.918.

=head1 METHODS

=over 4

=cut

package RDF::Query::Algebra::Shorthand;

our (@ISA, @EXPORT);
BEGIN {
	our $VERSION	= '2.918';
	
	require Exporter;
	@ISA	= qw(Exporter);
	@EXPORT	= qw(triple bgp ggp BGP Join OrderBy LeftJoin Project Filter Distinct Union Reduced Graph Slice Minus triple);
}

use strict;
use warnings;
no warnings 'redefine';

sub BGP {
	return RDF::Query::Algebra::BasicGraphPattern->new( @_ );
}

sub Join {
	return RDF::Query::Algebra::GroupGraphPattern->new( @_ );
}

sub OrderBy {
	return RDF::Query::Algebra::GroupGraphPattern->new( @_ );
}

sub LeftJoin {
	my ($p1, $p2)	= @_;
	my $a	= RDF::Query::Algebra::Optional->new( $p1, $p2 );
	if (scalar(@_) > 2) {
		$a	= RDF::Query::Algebra::Filter->new( $_[2], $a );
	}
	return $a;
}

sub Project {
	return RDF::Query::Algebra::Project->new( @_ );
}

sub Filter {
	return RDF::Query::Algebra::Filter->new( @_ );
}

sub Distinct {
	return RDF::Query::Algebra::Distinct->new( @_ );
}

sub Union {
	return RDF::Query::Algebra::Union->new( @_ );
}

sub Reduced {
	return RDF::Query::Algebra::Distinct->new( @_ );
}

sub Graph {
	return RDF::Query::Algebra::NamedGraph->new( @_ );
}

sub Slice {
	my ($p, $start, $length)	= @_;
	if ($start > 0) {
		$p	= RDF::Query::Algebra::Offset->new( $p, $start );
	}
	if ($length >= 0) {
		$p	= RDF::Query::Algebra::Limit->new( $p, $length );
	}
	return $p
}

sub Minus {
	return RDF::Query::Algebra::Minus->new( @_ );
}

sub triple {
	return RDF::Query::Algebra::Triple->new( @_ );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
