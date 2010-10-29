# RDF::Query::Node::Resource
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Resource - RDF Node class for resources

=head1 VERSION

This document describes RDF::Query::Node::Resource version 2.903_01.

=cut

package RDF::Query::Node::Resource;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Resource);

use URI;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.903_01';
}

######################################################################


=head1 METHODS

=over 4

=cut

use overload	'<=>'	=> \&_cmp,
				'cmp'	=> \&_cmp,
				'<'		=> sub { _cmp(@_) == -1 },
				'>'		=> sub { _cmp(@_) == 1 },
				'!='	=> sub { _cmp(@_) != 0 },
				'=='	=> sub { _cmp(@_) == 0 },
				'+'		=> sub { $_[0] },
				'""'	=> sub { $_[0]->sse },
			;

sub _cmp {
	my $a	= shift;
	my $b	= shift;
	return 1 unless blessed($b);
	return -1 if ($b->isa('RDF::Query::Node::Literal'));
	return 1 if ($b->isa('RDF::Query::Node::Blank'));
	return 0 unless ($b->isa('RDF::Query::Node::Resource'));
	my $cmp	= $a->uri_value cmp $b->uri_value;
	return $cmp;
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $ns		= $context->{ namespaces } || {};
	my %ns		= %$ns;
	return $self->sse( { namespaces => \%ns } );
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> 'node',
		iri			=> $self->uri_value,
	};
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
