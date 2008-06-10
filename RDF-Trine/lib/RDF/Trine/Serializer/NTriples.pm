# RDF::Trine::Serializer::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::NTriples - NTriples Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::NTriples version 0.107

=head1 SYNOPSIS

 use RDF::Trine::Serializer::NTriples;
 my $serializer	= RDF::Trine::Serializer::NTriples->new();

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer::NTriples;

use strict;
use warnings;

use URI;
use Carp;
use XML::SAX;
use Data::Dumper;
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 1;
	$VERSION	= 0.107;
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;
	my $self = bless( {}, $class);
	return $self;
}

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
}

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= join(' ', map { $_->sse } @nodes) . " .\n";
	}
	return $string;
}

1;

__END__

=end private

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut

