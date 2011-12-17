# RDF::Trine::Serializer::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::NTriples - N-Triples Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::NTriples version 0.136

=head1 SYNOPSIS

 use RDF::Trine::Serializer::NTriples;
 my $serializer	= RDF::Trine::Serializer::NTriples->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::NTriples class provides an API for serializing RDF
graphs to the N-Triples syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::NTriples;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use IO::Handle::Iterator;

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.136';
}
use RDF::Trine::Serializer -base => {
	serializer_names	=> [qw{ntriples}],
	format_uris			=> ['http://www.w3.org/ns/formats/N-Triples'],
	media_types			=> [qw{text/plain}],
	content_classes		=> [qw(RDF::Trine::Model RDF::Trine::Iterator::Graph)],
};

######################################################################

=item C<< new >>

Returns a new N-Triples serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to N-Triples, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
	my $io		= $self->serialize_model_to_io( $model );
	print {$file} $_ while (defined($_ = <$io>));
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to N-Triples, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_model_to_io ( $model ) >>

Returns an IO::Handle with the C<$model> serialized to N-Triples.

=cut

sub serialize_model_to_io {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	my $sub		= sub {
		my $st = $iter->next;
		return unless (blessed($st));
		return $self->statement_as_string( $st );
	};
	return IO::Handle::Iterator->new($sub);
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to N-Triples, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
	my $io		= $self->serialize_iterator_to_io( $iter );
	print {$file} $_ while (defined($_ = <$io>));
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to N-Triples, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_iterator_to_io ( $iter ) >>

Returns an IO::Handle with the C<$iter> serialized to N-Triples.

=cut

sub serialize_iterator_to_io {
	my $self	= shift;
	my $iter	= shift;
	my $sub		= sub {
		my $st		= $iter->next;
		return unless (blessed($st));
		return $self->statement_as_string( $st );
	};
	return IO::Handle::Iterator->new( $sub );
}

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	my $iter	= $model->get_statements( $node, undef, undef );
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
		if ($nodes[2]->isa('RDF::Trine::Node::Blank')) {
			$string	.= $self->_serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement object serialized as
N-Triples, ending in a DOT and newline.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	return join(' ', map { $_->as_ntriples } @nodes[0..2]) . " .\n";
}

=item C<< serialize_node ( $node ) >>

Returns a string containing the N-Triples serialization of C<< $node >>.

=cut

sub serialize_node {
	my $self	= shift;
	my $node	= shift;
	return $node->as_ntriples;
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-testcases/#ntriples>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
