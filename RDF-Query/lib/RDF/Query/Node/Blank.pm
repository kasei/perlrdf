# RDF::Query::Node::Blank
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Blank - RDF Node class for blank nodes

=head1 METHODS

=over 4

=cut

package RDF::Query::Node::Blank;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Blank);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.003_01';
}

######################################################################

use overload	'<=>'	=> \&_cmp,
				'cmp'	=> \&_cmp,
				'<'		=> sub { _cmp(@_[0,1]) == -1 },
				'>'		=> sub { _cmp(@_[0,1]) == 1 },
				'!='	=> sub { _cmp(@_[0,1]) != 0 },
				'=='	=> sub { _cmp(@_[0,1]) == 0 },
				'+'		=> sub { $_[0] },
				'""'	=> sub { $_[0]->sse },
			;

sub _cmp {
	my $nodea	= shift;
	my $nodeb	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.node.blank");
	$l->debug("blank comparison: " . Dumper($nodea, $nodeb));
	return 1 unless blessed($nodeb);
	return -1 if ($nodeb->isa('RDF::Query::Node::Literal'));
	return -1 if ($nodeb->isa('RDF::Query::Node::Resource'));
	return 1 unless ($nodeb->isa('RDF::Query::Node::Blank'));
	my $cmp	= $nodea->blank_identifier cmp $nodeb->blank_identifier;
	$l->debug("-> $cmp");
	return $cmp;
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
