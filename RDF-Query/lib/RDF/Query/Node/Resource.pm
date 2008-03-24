# RDF::Query::Node::Resource
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Resource - RDF Node class for resources

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

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

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

=head1 METHODS

=over 4

=cut


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
