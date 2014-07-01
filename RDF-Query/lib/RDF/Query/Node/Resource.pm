# RDF::Query::Node::Resource
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Resource - RDF Node class for resources

=head1 VERSION

This document describes RDF::Query::Node::Resource version 2.910.

=cut

package RDF::Query::Node::Resource;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Resource);

use URI;
use Encode;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################


=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Node> and L<RDF::Trine::Node::Resource> classes.

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
	if ($context) {
		my $uri		= $self->uri_value;
		my $ns		= $context->{namespaces} || {};
		my %ns		= %$ns;
		foreach my $k (keys %ns) {
			no warnings 'uninitialized';
			if ($k eq '__DEFAULT__') {
				$k	= '';
			}
			my $v	= $ns{ $k };
			if (index($uri, $v) == 0) {
				my $local	= substr($uri, length($v));
				if ($local =~ /^[A-Za-z_]+$/) {
					my $qname	= join(':', $k, $local);
					return $qname;
				}
			}
		}
	}
	
	my $string	= URI->new( encode_utf8($self->uri_value) )->canonical;
	my $sparql		= '<' . $string . '>';
	return $sparql;
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
