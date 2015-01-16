# RDF::Trine::Serializer::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFPatch - RDF-Patch Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::RDFPatch version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer::RDFPatch;
 my $serializer	= RDF::Trine::Serializer::RDFPatch->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::RDFPatch class provides an API for serializing RDF
graphs to the RDF-Patch syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::RDFPatch;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use List::Util qw(min);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);
use RDF::Trine::Exporter::RDFPatch;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'rdfpatch' }	= __PACKAGE__;
# 	$RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/ns/formats/RDF-Patch' }	= __PACKAGE__;
	foreach my $type (qw(application/rdf-patch)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

Returns a new RDF-Patch serializer object.

=cut

sub new {
	my $class	= shift;
	my %args;
	if (@_) {
		if (scalar(@_) == 1 and reftype($_[0]) eq 'HASH') {
			my $ns	= shift;
			%args	= ( namespaces => $ns );
		} else {
			%args	= @_;
		}
	}
	my $self	= bless({ args => [ %args ] }, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to RDF-Patch, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $model	= shift;
	
	my $sink	= RDF::Trine::Serializer::FileSink->new( $fh );
	my $e		= RDF::Trine::Exporter::RDFPatch->new( @{ $self->{args} }, sink => $sink );
	
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	while (my $st = $iter->next) {
		$e->add( $st );
	}
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to RDF-Patch, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;

	my $sink	= RDF::Trine::Serializer::StringSink->new();
	my $e		= RDF::Trine::Exporter::RDFPatch->new( @{ $self->{args} }, sink => $sink );

	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	while (my $st = $iter->next) {
		$e->add( $st );
	}
	
	return $sink->string;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to RDF-Patch, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	
	my $sink	= RDF::Trine::Serializer::FileSink->new( $fh );
	my $e		= RDF::Trine::Exporter::RDFPatch->new( @{ $self->{args} }, sink => $sink );
	
	while (my $st = $iter->next) {
		$e->add( $st );
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to RDF-Patch, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;

	my $sink	= RDF::Trine::Serializer::StringSink->new();
	my $e		= RDF::Trine::Exporter::RDFPatch->new( @{ $self->{args} }, sink => $sink );
	
	while (my $st = $iter->next) {
		$e->add( $st );
	}
	
	return $sink->string;
}

1;

__END__

=back

=head1 NOTES

As described in L<RDF::Trine::Node::Resource/as_ntriples>, serialization will
decode any L<punycode|http://www.ietf.org/rfc/rfc3492.txt> that is included in the IRI,
and serialize it using unicode codepoint escapes.

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://afs.github.io/rdf-patch/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
