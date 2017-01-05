# RDF::Query::Expression::Shorthand
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Shorthand - Base class for Expression expressions

=head1 VERSION

This document describes RDF::Query::Expression::Shorthand version 2.918.

=head1 METHODS

=over 4

=cut

package RDF::Query::Expression::Shorthand;

our (@ISA, @EXPORT);
BEGIN {
	our $VERSION	= '2.918';
	
	require Exporter;
	@ISA	= qw(Exporter);
	@EXPORT	= qw(Op Function);
}

use strict;
use warnings;
no warnings 'redefine';

sub Op {
	my $op		= shift;
	if (scalar(@_) == 1) {
		return RDF::Query::Expression::Unary->new( $op, @_ );
	} elsif (scalar(@_) == 2) {
		return RDF::Query::Expression::Binary->new( $op, @_ );
	} else {
		return RDF::Query::Expression::Nary->new( $op, @_ );
	}
}

sub Function {
	my $f	= shift;
	return RDF::Query::Expression::Function->new( $f, @_ );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
