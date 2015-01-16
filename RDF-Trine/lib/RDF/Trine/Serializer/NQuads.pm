# RDF::Trine::Serializer::NQuads
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::NQuads - N-Quads Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::NQuads version 1.012

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

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'nquads' }	= __PACKAGE__;
	$RDF::Trine::Serializer::format_uris{ 'http://sw.deri.org/2008/07/n-quads/#n-quads' }	= __PACKAGE__;
	foreach my $type (qw(text/x-nquads)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

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
	my $iter	= $model->as_stream;
	while (my $st = $iter->next) {
		print {$file} $self->_statement_as_string( $st );
	}
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

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to N-Quads, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
	while (my $st = $iter->next) {
		print {$file} $self->_statement_as_string( $st );
	}
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


=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement::Quad object serialized
as N-Quads, ending in a DOT and newline.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	return join(' ', map { $_->as_ntriples } @nodes[0..3]) . " .\n";
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://sw.deri.org/2008/07/n-quads/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
