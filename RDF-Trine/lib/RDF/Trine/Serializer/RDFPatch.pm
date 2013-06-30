# RDF::Trine::Serializer::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFPatch - RDF-Patch Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::RDFPatch version 1.005

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

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.005';
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
	my $ns	= {};

	if (@_) {
		if (scalar(@_) == 1 and reftype($_[0]) eq 'HASH') {
			$ns	= shift;
		} else {
			my %args	= @_;
			if (exists $args{ namespaces }) {
				$ns	= $args{ namespaces };
			}
		}
	}
	
	my %rev;
	while (my ($ns, $uri) = each(%{ $ns })) {
		if (blessed($uri)) {
			$uri	= $uri->uri_value;
			if (blessed($uri)) {
				$uri	= $uri->uri_value;
			}
		}
		$rev{ $uri }	= $ns;
	}
	
	my $self = bless( {
		ns		=> \%rev,
		last	=> [],
	}, $class );
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to RDF-Patch, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub _header {
	my $self	= shift;
	my %ns		= reverse(%{ $self->{ns} });
	my @nskeys	= sort keys %ns;
	my $header	= '';
	if (@nskeys) {
		foreach my $ns (sort @nskeys) {
			my $uri	= $ns{ $ns };
			$header	.= "\@prefix $ns: <$uri> .\n";
		}
		$header	.= "\n";
	}
	return $header;
}

sub serialize_model_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $model	= shift;
	
	my $header	= $self->_header();
	print $fh $header;
	
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	while (my $st = $iter->next) {
		print {$fh} $self->statement_as_string( $st );
	}
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to RDF-Patch, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	my $string	= $self->_header();
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to RDF-Patch, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	
	my $header	= $self->_header();
	print $fh $header;
	
	while (my $st = $iter->next) {
		print {$fh} $self->statement_as_string( $st );
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to RDF-Patch, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	
	my $string	= $self->_header();
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
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
		$string		.= $self->statement_as_string( $st );
		if ($nodes[2]->isa('RDF::Trine::Node::Blank')) {
			$string	.= $self->_serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement object serialized as
RDF-Patch, ending in a DOT and newline.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	my @str_nodes	= map { $self->node_as_concise_string($_) } @nodes;
	if (1) {
		foreach my $i (0 .. min(scalar(@nodes), scalar(@{$self->{'last'}}))) {
			if (defined($self->{'last'}[$i]) and $nodes[$i]->equal( $self->{'last'}[$i])) {
				$str_nodes[$i]	= 'R';
			}
		}
		@{ $self->{'last'} }	= @nodes;
	}
	return 'A ' . join(' ', @str_nodes) . " .\n";
}

=item C<< node_as_concise_string >>

Returns a string representation using RDF-Patch syntax shortcuts (e.g. PrefixNames).

=cut

sub node_as_concise_string {
	my $self	= shift;
	my $obj		= shift;
	if ($obj->isa('RDF::Trine::Node::Resource')) {
		my $value;
		try {
			my ($ns,$local)	= $obj->qname;
			if (blessed($self) and exists $self->{ns}{$ns}) {
				$value	= join(':', $self->{ns}{$ns}, $local);
				$self->{used_ns}{ $self->{ns}{$ns} }++;
			}
		} catch RDF::Trine::Error with {} otherwise {};
		if ($value) {
			return $value;
		}
	}
	return $obj->as_ntriples;
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
