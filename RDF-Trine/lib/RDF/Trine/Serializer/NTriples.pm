# RDF::Trine::Serializer::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::NTriples - NTriples Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::NTriples version 0.112_01

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

our ($VERSION);
BEGIN {
	$VERSION	= '0.112_01';
}

######################################################################

=item C<< new >>

Returns a new 

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $file, $model ) >>

Serializes the C<$model> to NTriples, printing the results to the supplied
C<$file> handle.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	while (my $st = $iter->next) {
		print {$file} join(' ', map { $_->as_ntriples } $st->nodes) . " .\n";
	}
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to NTriples, returning the result as a string.

=cut

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

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
