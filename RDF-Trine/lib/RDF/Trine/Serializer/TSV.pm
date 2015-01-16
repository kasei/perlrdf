# RDF::Trine::Serializer::TSV
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::TSV - TSV Serializer

=head1 VERSION

This document describes RDF::Trine::Store version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer::TSV;
 my $serializer	= RDF::Trine::Serializer::TSV->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::TSV class provides an API for serializing RDF
graphs to the TSV syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::TSV;

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
	$RDF::Trine::Serializer::serializer_names{ 'tsv' }	= __PACKAGE__;
	$RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/ns/formats/TSV' }	= __PACKAGE__;
	foreach my $type (qw(text/tsv)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

Returns a new TSV serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to TSV, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	print {$file} join("\t", qw(s p o));
	while (my $st = $iter->next) {
		print {$file} $self->statement_as_string( $st );
	}
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to TSV, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	my $string	= join("\t", qw(s p o)) . "\n";
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to TSV, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
	my $e		= $iter->peek;
	
	if (defined($e) and blessed($e) and $e->isa('RDF::Trine::Statement')) {
		print {$file} join("\t", qw(?s ?p ?o)) . "\n";
		while (my $st = $iter->next) {
			print {$file} $self->statement_as_string( $st );
		}
	} elsif (defined($e) and blessed($e) and $e->isa('RDF::Trine::VariableBindings')) {
		my @names	= $iter->binding_names;
		print {$file} join("\t", map { "?$_" } @names) . "\n";
		while (my $r = $iter->next) {
			print {$file} $self->result_as_string( $r, \@names );
		}
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to TSV, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	
	# TODO: must print the header line corresponding to the bindings in the entire iterator...
	my $string	= '';
	my $e		= $iter->peek;
	if (defined($e) and blessed($e) and $e->isa('RDF::Trine::Statement')) {
		$string	.= join("\t", qw(?s ?p ?o)) . "\n";
		while (my $st = $iter->next) {
			$string		.= $self->statement_as_string( $st );
		}
	} elsif (defined($e) and blessed($e) and $e->isa('RDF::Trine::VariableBindings')) {
		my @names	= $iter->binding_names;
		$string	.= join("\t", map { "?$_" } @names) . "\n";
		while (my $r = $iter->next) {
			$string		.= $self->result_as_string( $r, \@names );
		}
	}
	return $string;
}

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	# TODO: must print the header line, but only on the first (non-recursive) call to _serialize_bounded_description
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

=item C<< result_as_string ( $result, \@names ) >>

Returns a string with the bound terms of the given RDF::Trine::VariableBindings
corresponding to the given C<@names> serialized in N-Triples format, separated
by tab characters.

=cut

sub result_as_string {
	my $self	= shift;
	my $r		= shift;
	my $names	= shift;
	my @terms	= map { $r->{ $_ } } @$names;
	return join("\t", map { blessed($_) ? $_->as_ntriples : '' } @terms) . "\n";
}

=item C<< statement_as_string ( $st ) >>

Returns a string with the nodes of the given RDF::Trine::Statement serialized
in N-Triples format, separated by tab characters.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	return join("\t", map { $_->as_ntriples } @nodes[0..2]) . "\n";
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-testcases/#ntriples>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
