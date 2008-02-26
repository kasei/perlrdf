# RDF::Query::Node::Blank
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Blank - RDF Node class for blank nodes

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

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
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
	warn "blank comparison: " . Dumper($nodea, $nodeb) if ($debug);
	return 1 unless blessed($nodeb);
	return -1 if ($nodeb->isa('RDF::Query::Node::Literal'));
	return -1 if ($nodeb->isa('RDF::Query::Node::Resource'));
	return 1 unless ($nodeb->isa('RDF::Query::Node::Blank'));
	my $cmp	= $nodea->blank_identifier cmp $nodeb->blank_identifier;
	warn "-> $cmp\n" if ($debug);
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
