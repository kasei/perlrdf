# RDF::Trine::Serializer::TSV
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::TSV - TSV Serializer

=head1 VERSION

This document describes RDF::Trine::Store version 0.136

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
	serializer_names	=> [qw{tsv}],
	format_uris			=> ['http://www.w3.org/ns/formats/TSV'],
	media_types			=> [qw{text/tsv}],
	content_classes		=> [qw(RDF::Trine::Model RDF::Trine::Iterator::Graph)],
};

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
	my $io		= $self->serialize_model_to_io( $model );
	print {$file} $_ while (defined($_ = <$io>));
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
	
	my $string	= join("\t", qw(?s ?p ?o)) . "\n";
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
	}
	return $string;
}

=item C<< serialize_model_to_io ( $model ) >>

Returns an IO::Handle with the C<$model> serialized to TSV.

=cut

sub serialize_model_to_io {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	my $head	= 0;
	my $sub		= sub {
		unless ($head) {
			$head++;
			return join("\t", qw(?s ?p ?o)) . "\n";
		}
		my $st = $iter->next;
		return unless (blessed($st));
		return $self->statement_as_string( $st );
	};
	return IO::Handle::Iterator->new($sub);
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to TSV, printing the results to the supplied
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

Serializes the iterator to TSV, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	if ($iter->isa('RDF::Trine::Iterator::Bindings')) {
		my $i	= $iter->materialize;
		my %keys;
		while (my $r = $i->next) {
			foreach my $k (keys %{ $r }) {
				$keys{ $k }++;
			}
		}
		$i->reset;
		my @keys	= sort keys %keys;
		my $string	= join("\t", map { '?' . $_ } @keys) . "\n";
		while (my $r = $i->next) {
			my @nodes	= @{ $r }{ @keys };
			my @strings	= map { blessed($_) ? $_->as_ntriples : '' } @nodes;
			$string	.= join("\t", @strings) . "\n";
		}
	} else {
		# TODO: must print the header line corresponding to the bindings in the entire iterator...
		my $string	= '';
# 		$string	= join("\t", qw(?subject ?predicate ?object)) . "\n";
		while (my $st = $iter->next) {
			my @nodes	= $st->nodes;
			$string		.= $self->statement_as_string( $st );
		}
		return $string;
	}
}

=item C<< serialize_iterator_to_io ( $iter ) >>

Returns an IO::Handle with the C<$iter> serialized to TSV.

=cut

sub serialize_iterator_to_io {
	my $self	= shift;
	my $iter	= shift;
	if ($iter->isa('RDF::Trine::Iterator::Bindings')) {
		my $i	= $iter->materialize;
		my %keys;
		while (my $r = $i->next) {
			foreach my $k (keys %{ $r }) {
				$keys{ $k }++;
			}
		}
		$i->reset;
		my @keys	= sort keys %keys;
		
		my $head	= 0;
		my $sub		= sub {
			unless ($head) {
				$head++;
				return join("\t", map { '?' . $_ } @keys) . "\n";
			}
			my $r = $i->next;
			return unless (blessed($r));
			my @nodes	= @{ $r }{ @keys };
			my @strings	= map { blessed($_) ? $_->as_ntriples : '' } @nodes;
			return join("\t", @strings) . "\n";
		};
		return IO::Handle::Iterator->new( $sub );
	} else {
		# TODO: must print the header line corresponding to the bindings in the entire iterator...
# 		my $head	= 0;
		my $sub		= sub {
# 			unless ($head) {
# 				$head++;
# 				return join("\t", qw(?subject ?predicate ?object)) . "\n";
# 			}
			my $st = $iter->next;
			return unless (blessed($st));
			return $self->statement_as_string( $st );
		};
		return IO::Handle::Iterator->new( $sub );
	}
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

=item C<< statement_as_string ( $st ) >>

Returns a string with the nodes of the given RDF::Trine::Statement serialized in N-Triples format, separated by tab characters.

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

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-testcases/#ntriples>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
