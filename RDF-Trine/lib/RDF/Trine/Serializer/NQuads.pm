# RDF::Trine::Serializer::NQuads
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::NQuads - N-Quads Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::NQuads version 0.136

=head1 SYNOPSIS

 use RDF::Trine::Serializer::NQuads;
 my $serializer	= RDF::Trine::Serializer::NQuads->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::NQuads class provides an API for serializing RDF
graphs to the N-Quads syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::NQuads;

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
	isa             	=> [qw{RDF::Trine::Serializer::NTriples}],
	serializer_names	=> [qw{nquads}],
	format_uris			=> ['http://sw.deri.org/2008/07/n-quads/#n-quads'],
	media_types			=> [qw{text/x-nquads}],
	content_classes		=> [qw(RDF::Trine::Model RDF::Trine::Iterator::Graph)],
};

######################################################################

=item C<< new >>

Returns a new N-Quads serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to N-Quads, printing the results to the supplied
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

Serializes the C<$model> to N-Quads, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->_statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_model_to_io ( $model ) >>

Returns an IO::Handle with the C<$model> serialized to N-Quads.

=cut

sub serialize_model_to_io {
	my $self	= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	my $sub		= sub {
		my $st = $iter->next;
		return unless (blessed($st));
		return $self->_statement_as_string( $st );
	};
	return IO::Handle::Iterator->new($sub);
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to N-Quads, printing the results to the supplied
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

Serializes the iterator to N-Quads, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->_statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_iterator_to_io ( $iter ) >>

Returns an IO::Handle with the C<$iter> serialized to N-Quads.

=cut

sub serialize_iterator_to_io {
	my $self	= shift;
	my $iter	= shift;
	my $sub		= sub {
		my $st		= $iter->next;
		return unless (blessed($st));
		return $self->_statement_as_string( $st );
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
		$string		.= $self->_statement_as_string( $st );
		if ($nodes[2]->isa('RDF::Trine::Node::Blank')) {
			$string	.= $self->_serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

sub _statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes;
	if ($st->type eq 'TRIPLE') {
		@nodes	= $st->nodes;
	} else {
		my $g	= $st->context;
		if ($g->is_nil) {
			@nodes	= ($st->nodes)[0..2];
		} else {
			@nodes	= $st->nodes;
		}
	}
	return join(' ', map { $_->as_ntriples } @nodes) . " .\n";
}


1;

__END__

=back

=head1 SEE ALSO

L<http://sw.deri.org/2008/07/n-quads/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
