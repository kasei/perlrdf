# RDF::Trine::Serializer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer - RDF Serializer class

=head1 VERSION

This document describes RDF::Trine::Serializer version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer;

=head1 DESCRIPTION

The RDF::Trine::Serializer class provides an API for serializing RDF graphs
(via both model objects and graph iterators) to strings and files.

=cut

package RDF::Trine::Serializer;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use HTTP::Negotiate qw(choose);

our ($VERSION);
our %serializer_names;
our %format_uris;
our %media_types;
BEGIN {
	$VERSION	= '1.012';
}

use RDF::Trine::Serializer::NQuads;
use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::NTriples::Canonical;
use RDF::Trine::Serializer::RDFXML;
use RDF::Trine::Serializer::RDFJSON;
use RDF::Trine::Serializer::Turtle;
use RDF::Trine::Serializer::TriG;
use RDF::Trine::Serializer::RDFPatch;


=head1 METHODS

=over 4

=item C<< serializer_names >>

Returns a list of valid serializer names for use as arguments to the serializer constructor.

=cut

sub serializer_names {
	return keys %serializer_names;
}

=item C<< new ( $serializer_name, %options ) >>

Returns a new RDF::Trine::Serializer object for the serializer with the
specified name (e.g. "rdfxml" or "turtle"). If no serializer with the specified
name is found, throws a RDF::Trine::Error::SerializationError exception.

The valid key-values used in C<< %options >> are specific to a particular
serializer implementation. For serializers that support namespace declarations
(to allow more concise serialization), use C<< namespaces => \%namespaces >> in
C<< %options >>, where the keys of C<< %namespaces >> are namespace names and
the values are (partial) URIs. For serializers that support base URI declarations, 
use C<< base_uri => $base_uri >> .

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	my $key		= lc($name);
	$key		=~ s/[^-a-z]//g;
	
	if (my $class = $serializer_names{ $key }) {
		return $class->new( @_ );
	} else {
		throw RDF::Trine::Error::SerializationError -text => "No serializer known named $name";
	}
}

=item C<< negotiate ( request_headers => $request_headers, %options ) >>

Returns a two-element list containing an appropriate media type and
RDF::Trine::Serializer object as decided by L<HTTP::Negotiate>.  If
the C<< 'request_headers' >> key-value is supplied, the C<<
$request_headers >> is passed to C<< HTTP::Negotiate::choose >>.  The
option C<< 'restrict' >>, set to a list of serializer names, can be
used to limit the serializers to choose from. Finally, an C<<'extend' >> 
option can be set to a hashref that contains MIME-types
as keys and a custom variant as value. This will enable the user to
use this negotiator to return a type that isn't supported by any
serializers. The subsequent code will have to find out how to return a
representation. The rest of C<< %options >> is passed through to the
serializer constructor.

=cut

sub negotiate {
	my $class	= shift;
	my %options	= @_;
	my $headers	= delete $options{ 'request_headers' };
	my $restrict	= delete $options{ 'restrict' };
	my $extend	= delete $options{ 'extend' } || {};
	my %sclasses;
	if (ref($restrict) && ref($restrict) eq 'ARRAY') {
		$sclasses{ $serializer_names{$_} } = 1 for @$restrict;
	} else {
		%sclasses = reverse %serializer_names;
	}
	my @default_variants;
	while (my($type, $sclass) = each(%media_types)) {
		next unless $sclasses{$sclass};
		my $qv;
		# slightly prefer turtle as a readable format to others
		# try hard to avoid using ntriples as 'text/plain' isn't very useful for conneg
		if ($type eq 'text/turtle') {
			$qv	= 1.0;
		} elsif ($type eq 'text/plain') {
			$qv	= 0.2;
		} else {
			$qv	= 0.99;
		}
		$qv		-= 0.01 if ($type =~ m#/x-#);				# prefer non experimental media types
		$qv		-= 0.01 if ($type =~ m#^application/(?!rdf[+]xml)#);	# prefer standard rdf/xml to other application/* formats
		push(@default_variants, [$type, $qv, $type]);
	}
	
	my %custom_thunks;
	my @custom_variants;
	while (my($type,$thunk) = each(%$extend)) {
		push(@custom_variants, [$thunk, 1.0, $type]);
		$custom_thunks{ $thunk }	= [$type, $thunk];
	}
	
	# remove variants with media types that are in custom_variants from @variants
	my @variants	= grep { not exists $extend->{ $_->[2] } } @default_variants;
	push(@variants, @custom_variants);
	
	my $stype	= choose( \@variants, $headers );
	if (defined($stype) and $custom_thunks{ $stype }) {
		my $thunk	= $stype;
		my $type	= $custom_thunks{ $stype }[0];
		return ($type, $thunk);
	}
	
	if (defined($stype) and my $sclass = $media_types{ $stype }) {
		return ($stype, $sclass->new( %options ));
	} else {
		throw RDF::Trine::Error::SerializationError -text => "No appropriate serializer found for content-negotiation";
	}
}

=item C<< media_types >>

Returns a list of media types appropriate for the format of the serializer.

=cut

sub media_types {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my @list;
	while (my($type, $sclass) = each(%media_types)) {
		push(@list, $type) if ($sclass eq $class);
	}
	my @types	= sort @list;
	return @types;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<< $model >>, printing the results to the supplied filehandle
C<<$fh>>.

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<< $model >>, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $string	= '';
	open( my $fh, '>:encoding(UTF-8)', \$string );
	$self->serialize_model_to_file( $fh, $model );
	close($fh);
	return $string;
}

=item C<< serialize_iterator_to_file ( $file, $iterator ) >>

Serializes the statement objects produced by C<< $iterator >>, printing the
results to the supplied filehandle C<<$fh>>.

Note that some serializers may not support the use of this method, or may
require the full materialization of the iterator in order to serialize it.
If materialization is required, available memeory may constrain the iterators
that can be serialized.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	my %args	= @_;
	my $model	= RDF::Trine::Model->temporary_model;
	while (my $st = $iter->next) {
		$model->add_statement( $st );
	}
	return $self->serialize_model_to_file( $fh, $model );
}


=item C<< serialize_iterator_to_string ( $iterator ) >>

Serializes the statement objects produced by C<< $iterator >>, returning the
result as a string. Note that the same constraints apply to this method as to
C<< serialize_iterator_to_file >>.

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




=back

=cut

package RDF::Trine::Serializer::FileSink;

use strict;
use warnings;

=begin private

=head1 NAME

RDF::Trine::Serializer::FileSink

=head1 METHODS

=over 4

=cut

=item C<< new ( $fh ) >>

Returns a new serializer sink object backed by a filehandle.

=cut

sub new {
	my $class	= shift;
	my $fh		= shift;
	return bless([$fh],$class);
}

=item C<< emit ( $data ) >>

Write the C<< $data >> to the sink.

=cut

sub emit {
	my $self	= shift;
	my $data	= shift;
	print {$self->[0]} $data;
}

=back

=cut

package RDF::Trine::Serializer::StringSink;

use strict;
use warnings;
use Encode;

=head1 NAME

RDF::Trine::Serializer::StringSink

=head1 METHODS

=over 4

=cut

=item C<< new () >>

Returns a new serializer sink object backed by a string.

=cut

sub new {
	my $class	= shift;
	my $string	= decode_utf8("");
	return bless(\$string,$class);
}

=item C<< emit ( $data ) >>

Write the C<< $data >> to the sink.

=cut

sub emit {
	my $self	= shift;
	my $data	= shift;
	$$self		.= $data;
}

=item C<< prepend ( $data ) >>

Prepend the C<< $data >> to the underlying string.

=cut

sub prepend {
	my $self	= shift;
	my $data	= shift;
	$$self		= $data . $$self;
}

=item C<< string () >>

Returns the string value of all data written to the sink.

=cut

sub string {
	my $self	= shift;
	return $$self;
}

=back

=end private

=cut

1;

__END__

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
