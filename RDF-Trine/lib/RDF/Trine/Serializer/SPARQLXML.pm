# RDF::Trine::Serializer::SPARQLXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::SPARQLXML - SPARQL XML Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::SPARQLXML version 0.135

=head1 SYNOPSIS

 use RDF::Trine::Serializer::SPARQLXML;
 my $serializer	= RDF::Trine::Serializer::SPARQLXML->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::SPARQLXML class provides an API for serializing RDF
variable bindings sets to the SPARQL XML syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::SPARQLXML;

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
	$VERSION	= '0.135';
}
use RDF::Trine::Serializer -base => {
	serializer_names	=> [qw{sparqlxml}],
	format_uris			=> ['http://www.w3.org/ns/formats/SPARQL_Results_XML'],
	media_types			=> [qw{application/sparql-results+xml}],
	content_classes		=> [qw(RDF::Trine::Model RDF::Trine::Iterator::Bindings)],
};

######################################################################

=item C<< new >>

Returns a new SPARQLXML serializer object.

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

Serializes the C<$model> to SPARQL XML, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_string( $iter );
}

=item C<< serialize_model_to_io ( $model ) >>

Returns an IO::Handle with the C<$model> serialized to SPARQL/XML.

=cut

sub serialize_model_to_io {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_io( $iter );
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
	open( my $fh, '>', \$string );
	$self->serialize_iterator_to_file( $fh, $iter );
	close($fh);
	return $string;
}

=item C<< serialize_iterator_to_io ( $iter ) >>

Returns an IO::Handle with the C<$iter> serialized to SPARQL/XML.

=cut

sub serialize_iterator_to_io {
	my $self			= shift;
	my $iter			= shift;
	my $width			= $iter->bindings_count;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $iter->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my @lines	= (
		qq[<?xml version="1.0" encoding="utf-8"?>\n],
		qq[<sparql xmlns="http://www.w3.org/2005/sparql-results#">\n],
		qq[<head>\n],
		(map { qq(\t<variable name="$_"/>\n) } @variables),
		qq[</head>\n],
		qq[<results>\n],
	);
	
	my $foot	= 0;
	my $sub		= sub {
		while (1) {
			if (@lines) {
				return shift(@lines);
			}
			return if ($foot);
			my $row = $iter->next;
			unless (blessed($row)) {
				$foot++;
				push(@lines, "</results>\n");
				push(@lines, "</sparql>\n");
				next;
			}
			my @row;
			push(@lines, "\t\t<result>\n");
			for (my $i = 0; $i < $width; $i++) {
				my $name	= $iter->binding_name($i);
				my $value	= $row->{ $name };
				push(@lines, "\t\t\t" . $iter->format_node_xml($value, $name) . "\n");
			}
			push(@lines, "\t\t</result>\n");
		}
	};
	return IO::Handle::Iterator->new( $sub );
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-sparql-XMLres/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
